# Test-owned DSL for driving games at the domain layer. Tests speak only to
# this class (setup, actions, queries); it delegates to the real domain entry
# points. When a refactor moves those internals, re-point this class and the
# scenario suites stay unchanged.
class GameScenario
  class IllegalMove < StandardError; end

  # Fixed board sections (same set as game_replayer_test's known state) so
  # every scenario sees an identical map.
  DEFAULT_BOARDS = [ [ 1, 0 ], [ 5, 0 ], [ 0, 0 ], [ 4, 0 ] ].freeze
  DEFAULT_DECK = %w[T G C D F].freeze
  DEFAULT_HAND = "G".freeze

  attr_reader :game

  def initialize(players: 2, boards: DEFAULT_BOARDS, deck: DEFAULT_DECK,
                 goals: [], tasks: [], hands: {})
    @game = Game.create!(
      state: "playing",
      boards: boards.map(&:dup),
      board_contents: BoardState.new,
      deck: deck.dup,
      discard: [],
      goals: goals,
      tasks: tasks,
      mandatory_count: Game::MANDATORY_COUNT,
      move_count: 0,
      current_action: { "type" => "mandatory" }
    )
    players.times { |order| create_player(order, hands.fetch(order, DEFAULT_HAND)) }
    @game.update!(current_player: game_player(0))
    @game.update!(base_snapshot: @game.capture_snapshot)
  end

  # --- actions (domain intent; raise IllegalMove when the rules forbid it) ---

  def build_settlement(at:)
    perform { |engine| engine.build_settlement(*at) }
  end

  def undo
    perform { |engine| engine.undo_last_move }
  end

  # Activate a held tile's action (e.g. :resettlement, :paddock). The player
  # must already hold the corresponding tile.
  def activate_tile(type)
    perform { |engine| engine.select_action(type.to_s) }
  end

  def select_settlement(at:)
    perform { |engine| engine.select_settlement(*at) }
  end

  # One step of a stepped settlement move (resettlement, paddock, etc.).
  def move_step(to:)
    perform { |engine| engine.move_settlement(*to) }
  end

  # Select an on-board wagon/ship before moving it step by step.
  def select_meeple(at:)
    perform { |engine| engine.select_meeple_for_move(*at) }
  end

  # One step of a stepped wagon/ship move (or the initial placement).
  def move_meeple_step(to:)
    perform { |engine| engine.execute_meeple_action(*to) }
  end

  # --- setup (direct state construction; no rules applied) ---

  def place_tile(klass, at:, qty: 2)
    mutate_board { |contents| contents.place_tile(*at, klass, qty) }
  end

  def place_settlement(player, at:)
    mutate_board { |contents| contents.place_settlement(*at, player) }
  end

  def place_wagon(player, at:)
    mutate_board { |contents| contents.place_wagon(*at, player) }
  end

  def place_ship(player, at:)
    mutate_board { |contents| contents.place_ship(*at, player) }
  end

  def give_tile(player, klass, from:, used: false)
    gp = game_player(player)
    gp.restore_tile!(klass, from: Coordinate.new(*from).to_key, used: used)
    gp.save!
  end

  # --- queries ---

  def owner_at(at)
    @game.board_contents.player_at(*at)
  end

  def holds_tile?(player, klass: nil, from: nil)
    from = Coordinate.new(*from).to_key if from.is_a?(Array)
    game_player(player).holds_tile?(klass: klass, from: from)
  end

  # Raw held-tile hashes (klass/from/used), optionally filtered by klass.
  def held_tiles(player, klass: nil)
    tiles = game_player(player).tiles || []
    klass ? tiles.select { |t| t["klass"] == klass } : tiles
  end

  def tile_qty(at)
    @game.board_contents.tile_qty(*at)
  end

  def neighbors(at)
    @game.board_contents.neighbors(*at)
  end

  def terrain_at(at)
    fresh_board.terrain_at(*at)
  end

  def legal_builds(player)
    @game.legal_builds(game_player(player))
  end

  def score_for(goal, player)
    fresh_board
    @game.score_for(goal, game_player(player))
  end

  def usable_tiles(player)
    game_player(player).usable_tiles.map { |t| t["klass"] }
  end

  def available_tile_actions(player)
    fresh_board
    @game.available_tile_actions(game_player(player)).map { |t| t["klass"] }
  end

  def settlements_remaining(player)
    game_player(player).settlements_remaining
  end

  def mandatory_remaining
    @game.mandatory_count
  end

  # Deterministic on a fixed board: scans row-major for empty hexes of the
  # given terrain.
  def empty_hexes(terrain, count)
    board = fresh_board
    spots = []
    20.times do |row|
      20.times do |col|
        next unless board.terrain_at(row, col) == terrain
        next unless @game.board_contents.empty?(row, col)
        spots << [ row, col ]
        return spots if spots.size >= count
      end
    end
    spots
  end

  def game_player(order)
    @game.game_players.find_by!(order: order)
  end

  # Canonical, order-normalized game state for round-trip comparison. Mirrors
  # the fields game_replayer_test treats as the replayable state.
  def snapshot
    state = @game.capture_snapshot
    state.merge(
      "board_contents" => state["board_contents"].sort_by { |e| [ e["r"], e["c"] ] },
      "players" => state["players"].sort_by { |p| p["order"] }
    )
  end

  private

  def create_player(order, hand)
    user = User.create!(
      handle: "scenario-#{@game.id}-p#{order}",
      email_address: "scenario-#{@game.id}-p#{order}@example.com",
      password: "password",
      approved: true
    )
    GamePlayer.create!(
      game: @game,
      player: user,
      order: order,
      hand: Array(hand),
      supply: { "settlements" => Game::SETTLEMENTS_PER_PLAYER },
      tiles: []
    )
  end

  def mutate_board
    @game.board_contents_will_change!
    yield @game.board_contents
    @game.board = nil
    @game.save!
  end

  def perform
    @game.board = nil
    result = yield TurnEngine.new(@game)
    raise IllegalMove, result if result.is_a?(String)
    @game.reload
    @game.board = nil
    result
  end

  # Memoized via Game#instantiate_board; perform/mutate_board reset @game.board
  # to nil after any state change, so this only rebuilds when stale.
  def fresh_board
    @game.instantiate
  end
end
