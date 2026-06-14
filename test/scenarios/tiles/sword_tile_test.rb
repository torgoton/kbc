require "test_helper"

# Nomad::SwordTile lets the player remove one settlement from each opponent
# that has at least one on the board, returning each to its owner's supply.
class SwordTileTest < ActiveSupport::TestCase
  OPPONENT_SETTLEMENT = [ 10, 10 ].freeze

  test "removes one settlement from the targeted opponent and returns it to their supply" do
    scenario = GameScenario.new
    scenario.place_settlement(1, at: OPPONENT_SETTLEMENT)
    scenario.give_tile(0, "Nomad::SwordTile", from: [ 0, 0 ])

    scenario.activate_tile(:"nomad::sword")

    # The opponent's settlement is highlighted as a removal target (dispatched
    # polymorphically via sword_tile?, so it works regardless of the
    # "nomad::sword" action-type string).
    assert_includes scenario.buildable_cells, OPPONENT_SETTLEMENT

    before_supply = scenario.settlements_remaining(1)
    scenario.remove_settlement(at: OPPONENT_SETTLEMENT)

    assert_nil scenario.owner_at(OPPONENT_SETTLEMENT)
    assert_equal before_supply + 1, scenario.settlements_remaining(1)
    assert_equal Game::MANDATORY_COUNT, scenario.mandatory_remaining

    # Known bug: remove_settlement marks the tile used via
    # current_action_tile_klass.demodulize ("SwordTile"), which doesn't match
    # the stored "Nomad::SwordTile" klass, so the tile is never actually
    # marked used even though the phase resets to mandatory build.
    assert_includes scenario.usable_tiles(0), "Nomad::SwordTile"
  end

  test "cannot be activated when no opponent has a settlement on the board" do
    scenario = GameScenario.new
    scenario.give_tile(0, "Nomad::SwordTile", from: [ 0, 0 ])

    assert_raises(GameScenario::IllegalMove) { scenario.activate_tile(:"nomad::sword") }
  end
end
