require "test_helper"

# Nomad::TreasureTile is a pure scoring tile: picking it up immediately
# scores 3 points (instead of being held like other Nomad tiles).
class TreasureTileTest < ActiveSupport::TestCase
  test "picking up the tile immediately scores 3 points and is not held" do
    scenario = GameScenario.new(hands: { 0 => "G", 1 => "D" })
    spot = scenario.empty_hexes("G", 1).first
    tile_spot = scenario.neighbors(spot).first
    scenario.place_tile("TreasureTile", at: tile_spot, qty: 1)

    scenario.build_settlement(at: spot)

    assert_equal 3, scenario.score_for("treasure", 0)
    assert_not scenario.holds_tile?(0, klass: "TreasureTile")
    assert_equal 0, scenario.tile_qty(tile_spot)
  end
end
