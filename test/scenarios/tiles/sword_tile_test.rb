require "test_helper"

# SwordTile lets the player remove one settlement from each opponent that has
# at least one on the board, returning each to its owner's supply.
class SwordTileTest < ActiveSupport::TestCase
  OPPONENT_SETTLEMENT = [ 10, 10 ].freeze

  test "removes one settlement from the targeted opponent and returns it to their supply" do
    scenario = GameScenario.new
    scenario.place_settlement(1, at: OPPONENT_SETTLEMENT)
    scenario.give_tile(0, "SwordTile", from: [ 0, 0 ])

    scenario.activate_tile(:sword)

    # The opponent's settlement is highlighted as a removal target (dispatched
    # polymorphically via sword_tile?).
    assert_includes scenario.buildable_cells, OPPONENT_SETTLEMENT

    before_supply = scenario.settlements_remaining(1)
    scenario.remove_settlement(at: OPPONENT_SETTLEMENT)

    assert_nil scenario.owner_at(OPPONENT_SETTLEMENT)
    assert_equal before_supply + 1, scenario.settlements_remaining(1)
    assert_equal Game::MANDATORY_COUNT, scenario.mandatory_remaining

    # The removal completes the action: the tile is marked used and the phase
    # resets to mandatory build.
    assert_not_includes scenario.usable_tiles(0), "SwordTile"
  end

  test "cannot be activated when no opponent has a settlement on the board" do
    scenario = GameScenario.new
    scenario.give_tile(0, "SwordTile", from: [ 0, 0 ])

    assert_raises(GameScenario::IllegalMove) { scenario.activate_tile(:sword) }
  end
end
