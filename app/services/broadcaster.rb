# Broadcaster — translates a consequence list into Turbo Stream broadcast plans.
#
# Slice 1: emits stub html for each plan. Slice 1.5 will swap in the real
# partials (board, turn_state, game_player) once the new stack is wired
# through the controller and the partials' locals are sourced from Turn /
# sub-phase state instead of TurnEngine.
class Broadcaster
  Plan = Data.define(:channel, :target, :html)

  def self.publish(game, consequences)
    new(game, consequences).publish
  end

  def initialize(game, consequences)
    @game = game
    @consequences = Array(consequences)
  end

  def plans
    @plans ||= compute_plans
  end

  def publish
    plans.each do |p|
      Turbo::StreamsChannel.broadcast_update_to(p.channel, target: p.target, html: p.html)
    end
    plans
  end

  private

  def compute_plans
    out = []
    out << Plan.new("game_#{@game.id}", "board", stub("board")) if board_changed?
    out << Plan.new("game_#{@game.id}", "turn-state", stub("turn-state")) if turn_state_changed?
    affected_players.each do |gp|
      out << Plan.new("game_player_#{gp.id}_private", "game_player_#{gp.id}", stub("game_player_#{gp.id}"))
    end
    out
  end

  def board_changed?
    @consequences.any? { |c| board_changing?(c) }
  end

  def turn_state_changed?
    @consequences.any? { |c| turn_state_changing?(c) }
  end

  def board_changing?(c)
    c.is_a?(Turn::Consequences::SettlementPlaced) || c.is_a?(Turn::Consequences::TilePickedUp)
  end

  def turn_state_changing?(c)
    c.is_a?(Turn::Consequences::SubPhasePushed) ||
      c.is_a?(Turn::Consequences::SubPhasePopped) ||
      board_changing?(c)
  end

  def affected_players
    orders = Set.new
    @consequences.each do |c|
      orders << c.player if c.respond_to?(:player)
    end
    @game.game_players.select { |gp| orders.include?(gp.order) }
  end

  def stub(target)
    %(<div data-broadcaster-target="#{target}"></div>)
  end
end
