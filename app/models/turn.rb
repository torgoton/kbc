# Turn — container for a single player's turn.
#
# Owns turn-level state and the transitions between sub-phases. Reconstructed
# per request from Game.current_action["turn"]. Sub-phases are pushed onto the
# turn when activated and popped on completion; the turn decides what's
# available next, the sub-phase only knows how to do its own job.
#
# Convention: params from the controller arrive as (row, col) integers; the
# first thing each entry point does is build a Coordinate. Only Coordinate
# (and the legacy storage layer it serializes to) ever sees the "[r, c]"
# string form.
class Turn
  attr_reader :player_order, :sub_phase, :mandatory_remaining, :builds_this_turn, :outpost_active

  DEFAULT_MANDATORY = 3

  def initialize(player_order:, sub_phase: nil, mandatory_remaining: DEFAULT_MANDATORY, builds_this_turn: [], outpost_active: false)
    @player_order = player_order
    @sub_phase = sub_phase
    @mandatory_remaining = mandatory_remaining
    @builds_this_turn = builds_this_turn
    @outpost_active = outpost_active
  end

  def self.from_game(game)
    raw = (game.current_action.is_a?(Hash) ? game.current_action["turn"] : nil) || {}
    new(
      player_order: game.current_player&.order,
      sub_phase: parse_sub_phase(raw["sub_phase"]),
      mandatory_remaining: raw.fetch("mandatory_remaining", DEFAULT_MANDATORY),
      builds_this_turn: parse_builds(raw["builds"]),
      outpost_active: raw.fetch("outpost_active", false)
    )
  end

  def to_h
    {
      "sub_phase" => sub_phase ? sub_phase_payload(sub_phase) : nil,
      "mandatory_remaining" => mandatory_remaining,
      "builds_this_turn" => builds_this_turn.map { |r, c| Coordinate.new(r, c).to_key },
      "outpost_active" => outpost_active
    }
  end

  def handle(action_name, game:, **params)
    case action_name
    when :select_action
      handle_select_action(game:, **params)
    when :build
      handle_build(game:, **params)
    when :activate_outpost
      handle_activate_outpost(game:)
    when :activate_fort
      handle_activate_fort(game:)
    when :end_turn
      handle_end_turn(game:)
    else
      [ error("unsupported turn action: #{action_name}") ]
    end
  end

  private

  def handle_select_action(game:, tile:)
    return [ error("a sub-phase is already active") ] if sub_phase

    klass_name = tile.to_s
    tile_class = Tiles::Tile.for_klass(klass_name)
    return [ error("unknown tile: #{klass_name}") ] unless tile_class

    instance = tile_class.new(0)
    if instance.builds_settlement? && instance.build_terrain
      activate_fixed_terrain_build(game:, klass_name:, terrain: instance.build_terrain)
    else
      [ error("tile #{klass_name} is not activatable via select_action") ]
    end
  end

  def activate_fixed_terrain_build(game:, klass_name:, terrain:)
    gp = game.game_players.find { |g| g.order == player_order }
    return [ error("no current player") ] unless gp

    held = gp.find_unused_tile(klass_name)
    return [ error("no unused #{klass_name} available") ] unless held

    pushed = Turn::SubPhases::TileBuildPhase.new(
      restricted_terrain: terrain,
      tile_klass: klass_name,
      tile_source: Coordinate.from_key(held["from"])
    )
    [
      Turn::Consequences::SubPhasePushed.new(
        phase_type: Turn::SubPhases::TileBuildPhase::TYPE,
        state: pushed.to_h
      )
    ]
  end

  def handle_build(game:, **params)
    if sub_phase
      handle_sub_phase_build(game:, **params)
    else
      handle_mandatory_build(game:, **params)
    end
  end

  def handle_sub_phase_build(game:, **params)
    prior_state = sub_phase_payload(sub_phase)
    consequences = sub_phase.handle(:build, game:, player_order:, **params)
    consequences << Turn::Consequences::SubPhasePopped.new(prior_state: prior_state) if sub_phase.complete?
    consequences
  end

  def handle_end_turn(game:)
    gp = game.game_players.find { |g| g.order == player_order }
    return [ error("no current player") ] unless gp

    hand_before = Array(gp.hand)
    deck_before = (game.deck || []).dup
    discard_before = (game.discard || []).dup

    # Discard the player's hand, then draw one card (or two if they hold a
    # CrossroadsTile). Reshuffle from discard whenever the deck would be empty.
    # Randomness is decided here so the consequence carries deterministic
    # before/after state.
    draw_count = has_crossroads_tile?(gp) ? 2 : 1
    discard_after = discard_before + hand_before
    pool = deck_before.dup
    drawn = []
    draw_count.times do
      if pool.empty? && discard_after.any?
        pool = discard_after.shuffle
        discard_after = []
      end
      break if pool.empty?
      drawn << pool.shift
    end
    deck_after = pool
    if deck_after.empty? && discard_after.any?
      deck_after = discard_after.shuffle
      discard_after = []
    end
    hand_after = drawn

    next_order = (player_order + 1) % game.game_players.count
    next_player = game.game_players.find { |g| g.order == next_order }
    prior_turn_state = game.current_action.is_a?(Hash) ? game.current_action["turn"] : nil
    completed = game_complete_for(game)
    tiles_reset = next_player ? [ Turn::Consequences::TilesReset.new(player: next_order, prior_tiles: (next_player.tiles || []).deep_dup) ] : []
    expired = expired_nomad_tiles_for(gp, game)

    [
      Turn::Consequences::HandRefreshed.new(
        player: player_order,
        hand_before: hand_before,
        hand_after: hand_after,
        deck_before: deck_before,
        deck_after: deck_after,
        discard_before: discard_before,
        discard_after: discard_after
      ),
      Turn::Consequences::CurrentPlayerAdvanced.new(prior_order: player_order, next_order: next_order),
      *tiles_reset,
      *expired,
      Turn::Consequences::TurnReset.new(prior_turn_number: game.turn_number, prior_turn_state: prior_turn_state),
      *completed,
      Turn::Consequences::IrreversibleBoundary.new
    ]
  end

  def expired_nomad_tiles_for(gp, game)
    expired = (gp.tiles || []).select { |t| t["expires_on_turn"] == game.turn_number }
    return [] if expired.empty?
    [ Turn::Consequences::NomadTilesExpired.new(player: player_order, expired_tiles: expired.deep_dup) ]
  end

  def has_crossroads_tile?(gp)
    (gp.tiles || []).any? { |t| t["klass"] == "CrossroadsTile" }
  end

  def game_complete_for(game)
    return [] unless game.ending?
    last_order = game.game_players.count - 1
    return [] unless player_order == last_order
    [ Turn::Consequences::GameCompleted.new(prior_state: game.state, prior_scores: game.scores) ]
  end

  def handle_activate_fort(game:)
    return [ error("a sub-phase is already active") ] if sub_phase

    gp = game.game_players.find { |g| g.order == player_order }
    return [ error("no current player") ] unless gp
    return [ error("no unused FortTile") ] unless gp.find_unused_tile("FortTile")
    return [ error("no settlements remaining") ] unless gp.settlements_remaining > 0

    deck_before = (game.deck || []).dup
    discard_before = (game.discard || []).dup
    return [ error("deck is empty") ] if deck_before.empty? && discard_before.empty?

    drawn = deck_before.first
    remaining_deck = deck_before[1..]
    if remaining_deck.empty?
      remaining_deck = discard_before.shuffle
      discard_after = [ drawn ]
    else
      discard_after = discard_before + [ drawn ]
    end
    deck_after = remaining_deck

    pushed = Turn::SubPhases::FortPhase.new(fort_terrain: drawn, builds_remaining: 2)

    [
      Turn::Consequences::TileConsumed.new(klass: "FortTile", player: player_order),
      Turn::Consequences::CardDrawn.new(
        card: drawn,
        deck_before: deck_before,
        discard_before: discard_before,
        deck_after: deck_after,
        discard_after: discard_after
      ),
      Turn::Consequences::SubPhasePushed.new(phase_type: Turn::SubPhases::FortPhase::TYPE, state: pushed.to_h),
      Turn::Consequences::IrreversibleBoundary.new
    ]
  end

  def handle_activate_outpost(game:)
    return [ error("outpost already active") ] if outpost_active

    gp = game.game_players.find { |g| g.order == player_order }
    return [ error("no current player") ] unless gp
    return [ error("no unused OutpostTile") ] unless gp.find_unused_tile("OutpostTile")

    [
      Turn::Consequences::OutpostActivated.new(prior_active: outpost_active),
      Turn::Consequences::TileConsumed.new(klass: "OutpostTile", player: player_order)
    ]
  end

  def handle_mandatory_build(game:, row:, col:)
    return [ error("no builds remaining this turn") ] if mandatory_remaining <= 0

    gp = game.game_players.find { |g| g.order == player_order }
    return [ error("no current player") ] unless gp

    terrain = gp.hand&.first
    return [ error("no terrain card in hand") ] unless terrain

    game.instantiate
    return [ error("not a valid mandatory build target") ] unless
      game.board_contents.can_mandatory_build?(game.board, player_order, terrain, row, col, skip_adjacency: outpost_active)

    pickups = game.board_contents.pickup_targets_for(row, col, gp.taken_from).map do |coord, klass|
      Turn::Consequences::TilePickedUp.new(from: coord, klass: klass, player: player_order)
    end

    grants = pickups.flat_map { |pickup| meeple_grant_for(pickup) }
    immediate = pickups.flat_map { |pickup| immediate_score_for(pickup, gp) }
    goals = goal_scores_for(game, gp, terrain, row, col)
    families = families_score_for(game, gp, row, col)
    outpost_consume = outpost_active ? [ Turn::Consequences::OutpostDeactivated.new(prior_active: true) ] : []
    end_trigger = Turn::Consequences::EndTriggered.maybe(game: game, player_order: player_order)

    [
      Turn::Consequences::SettlementPlaced.new(at: Coordinate.new(row, col), player: player_order, terrain: terrain),
      *end_trigger,
      *pickups,
      *grants,
      *immediate,
      *goals,
      *families,
      *outpost_consume,
      Turn::Consequences::BuildRecorded.new(at: Coordinate.new(row, col).to_key),
      Turn::Consequences::MandatoryRemainingDecremented.new(prior_remaining: mandatory_remaining)
    ]
  end

  def families_score_for(game, gp, row, col)
    return [] unless Array(game.goals).include?("families")
    sequence = builds_this_turn + [ [ row, col ] ]
    return [] unless sequence.size == 3
    return [] unless straight_line?(sequence)
    [ goal_scored(gp, "families", 2) ]
  end

  def straight_line?(positions)
    a, b, c = positions
    [ [ a, b, c ], [ a, c, b ], [ b, a, c ] ].any? { |p1, p2, p3| in_same_direction?(p1, p2, p3) }
  end

  def in_same_direction?(p1, p2, p3)
    Tiles::PaddockTile::STRAIGHT_LINES.any? do |steps|
      dr1, dc1 = steps[p1[0] % 2]
      mid = [ p1[0] + dr1, p1[1] + dc1 ]
      next false unless mid == p2
      dr2, dc2 = steps[p2[0] % 2]
      far = [ p2[0] + dr2, p2[1] + dc2 ]
      far == p3
    end
  end

  def goal_scores_for(game, gp, terrain, row, col)
    active = Array(game.goals)
    out = []
    if active.include?("ambassadors") && game.board_contents.ambassadors_match?(player_order, row, col)
      out << goal_scored(gp, "ambassadors", 1)
    end
    if active.include?("shepherds") && game.board_contents.shepherds_match?(game.board, terrain, row, col)
      out << goal_scored(gp, "shepherds", 2)
    end
    out
  end

  def goal_scored(gp, goal, points)
    prior = gp.bonus_scores&.dig(goal) || 0
    Turn::Consequences::GoalScored.new(player: player_order, goal: goal, points: points, prior_score: prior)
  end

  def meeple_grant_for(pickup)
    grant = Tiles::Tile.for_klass(pickup.klass)&.new(0)&.meeple_grant
    return [] unless grant
    [ Turn::Consequences::MeepleGranted.new(player: player_order, kind: grant["kind"], qty: grant["qty"]) ]
  end

  def immediate_score_for(pickup, gp)
    score = Tiles::Tile.for_klass(pickup.klass)&.new(0)&.immediate_score
    return [] unless score
    prior = gp.bonus_scores&.dig(score["goal"]) || 0
    [
      Turn::Consequences::GoalScored.new(player: player_order, goal: score["goal"], points: score["points"], prior_score: prior),
      Turn::Consequences::TileDiscarded.new(player: player_order, klass: pickup.klass, from: pickup.from.to_key, used: true)
    ]
  end

  def error(msg)
    Turn::Consequences::Error.new(message: msg)
  end

  def sub_phase_payload(sp)
    type = sp.class.const_defined?(:TYPE) ? sp.class::TYPE : sp.class.name
    { "type" => type, "state" => sp.to_h }
  end

  class << self
    private

    def parse_sub_phase(hash)
      return nil unless hash.is_a?(Hash)

      case hash["type"]
      when Turn::SubPhases::TileBuildPhase::TYPE
        Turn::SubPhases::TileBuildPhase.from_h(hash["state"] || {})
      when Turn::SubPhases::FortPhase::TYPE
        Turn::SubPhases::FortPhase.from_h(hash["state"] || {})
      end
    end

    def parse_builds(raw)
      Array(raw).map { |key| coord = Coordinate.from_key(key); [ coord.row, coord.col ] }
    end
  end
end
