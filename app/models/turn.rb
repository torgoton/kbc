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
  attr_reader :player_order, :sub_phase, :mandatory_remaining

  DEFAULT_MANDATORY = 3

  def initialize(player_order:, sub_phase: nil, mandatory_remaining: DEFAULT_MANDATORY)
    @player_order = player_order
    @sub_phase = sub_phase
    @mandatory_remaining = mandatory_remaining
  end

  def self.from_game(game)
    raw = (game.current_action.is_a?(Hash) ? game.current_action["turn"] : nil) || {}
    new(
      player_order: game.current_player&.order,
      sub_phase: parse_sub_phase(raw["sub_phase"]),
      mandatory_remaining: raw.fetch("mandatory_remaining", DEFAULT_MANDATORY)
    )
  end

  def to_h
    {
      "sub_phase" => sub_phase ? sub_phase_payload(sub_phase) : nil,
      "mandatory_remaining" => mandatory_remaining
    }
  end

  def handle(action_name, game:, **params)
    case action_name
    when :select_action
      handle_select_action(game:, **params)
    when :build
      handle_build(game:, **params)
    else
      [ error("unsupported turn action: #{action_name}") ]
    end
  end

  private

  def handle_select_action(game:, tile:)
    return [ error("a sub-phase is already active") ] if sub_phase

    case tile
    when :farm
      handle_farm_activation(game:)
    else
      [ error("unsupported tile: #{tile}") ]
    end
  end

  def handle_farm_activation(game:)
    gp = game.game_players.find { |g| g.order == player_order }
    return [ error("no current player") ] unless gp

    held = gp.find_unused_tile("FarmTile")
    return [ error("no unused Farm tile available") ] unless held

    pushed = Turn::SubPhases::TileBuildPhase.new(
      restricted_terrain: "G",
      tile_klass: "FarmTile",
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

  def handle_mandatory_build(game:, row:, col:)
    return [ error("no builds remaining this turn") ] if mandatory_remaining <= 0

    gp = game.game_players.find { |g| g.order == player_order }
    return [ error("no current player") ] unless gp

    terrain = gp.hand&.first
    return [ error("no terrain card in hand") ] unless terrain

    game.instantiate
    return [ error("not a valid mandatory build target") ] unless
      game.board_contents.can_mandatory_build?(game.board, player_order, terrain, row, col)

    pickups = game.board_contents.pickup_targets_for(row, col, gp.taken_from).map do |coord, klass|
      Turn::Consequences::TilePickedUp.new(from: coord, klass: klass, player: player_order)
    end

    grants = pickups.flat_map { |pickup| meeple_grant_for(pickup) }

    [
      Turn::Consequences::SettlementPlaced.new(at: Coordinate.new(row, col), player: player_order, terrain: terrain),
      *pickups,
      *grants,
      Turn::Consequences::MandatoryRemainingDecremented.new(prior_remaining: mandatory_remaining)
    ]
  end

  def meeple_grant_for(pickup)
    grant = Tiles::Tile.for_klass(pickup.klass)&.new(0)&.meeple_grant
    return [] unless grant
    [ Turn::Consequences::MeepleGranted.new(player: player_order, kind: grant["kind"], qty: grant["qty"]) ]
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
      end
    end
  end
end
