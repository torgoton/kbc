require "test_helper"

class TileUsabilityScenarioTest < ActiveSupport::TestCase
  test "a tile held from a previous turn is usable" do
    scenario = GameScenario.new(hands: { 0 => "G", 1 => "D" })
    scenario.give_tile(0, "FarmTile", from: [ 2, 7 ])

    assert_equal [ "FarmTile" ], scenario.usable_tiles(0)
  end

  test "tile actions are available before mandatory builds begin but not mid-build" do
    scenario = GameScenario.new(hands: { 0 => "G", 1 => "D" })
    scenario.give_tile(0, "OasisTile", from: [ 2, 7 ])

    assert_equal [ "OasisTile" ], scenario.available_tile_actions(0)

    scenario.build_settlement(at: scenario.empty_hexes("G", 1).first)

    assert_empty scenario.available_tile_actions(0)
  end

  test "a tile picked up this turn arrives spent and is not usable until next turn" do
    scenario = GameScenario.new(hands: { 0 => "G", 1 => "D" })
    spot = scenario.empty_hexes("G", 1).first
    scenario.place_tile("FarmTile", at: scenario.neighbors(spot).first, qty: 2)

    scenario.build_settlement(at: spot)

    assert scenario.holds_tile?(0, klass: "FarmTile")
    assert_empty scenario.usable_tiles(0)
  end
end
