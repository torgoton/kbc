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
  attr_reader :player_order, :sub_phase

  def initialize(player_order:, sub_phase: nil)
    @player_order = player_order
    @sub_phase = sub_phase
  end

  def self.from_game(game)
    raw = (game.current_action.is_a?(Hash) ? game.current_action["turn"] : nil) || {}
    new(
      player_order: game.current_player&.order,
      sub_phase: parse_sub_phase(raw["sub_phase"])
    )
  end

  def to_h
    {
      "sub_phase" => sub_phase ? sub_phase_payload(sub_phase) : nil
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
    return [ error("no active sub-phase") ] unless sub_phase

    prior_state = sub_phase_payload(sub_phase)
    consequences = sub_phase.handle(:build, game:, player_order:, **params)
    consequences << Turn::Consequences::SubPhasePopped.new(prior_state: prior_state) if sub_phase.complete?
    consequences
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
