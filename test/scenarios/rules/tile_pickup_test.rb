require "test_helper"

class TilePickupScenarioTest < ActiveSupport::TestCase
  test "building adjacent to a location hex with remaining tiles picks one up" do
    scenario = GameScenario.new(hands: { 0 => "G", 1 => "D" })
    spot = scenario.empty_hexes("G", 1).first
    tile_spot = scenario.neighbors(spot).first
    scenario.place_tile("OasisTile", at: tile_spot, qty: 2)

    scenario.build_settlement(at: spot)

    assert scenario.holds_tile?(0, klass: "OasisTile", from: tile_spot)
    assert_equal 1, scenario.tile_qty(tile_spot)
  end

  test "building away from any location hex picks up nothing" do
    scenario = GameScenario.new(hands: { 0 => "G", 1 => "D" })
    spot = scenario.empty_hexes("G", 1).first

    scenario.build_settlement(at: spot)

    assert_not scenario.holds_tile?(0, klass: "OasisTile")
  end
end
