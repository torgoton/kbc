require "test_helper"

# CityHallTile: picking it up grants a City Hall to the player's supply.
# Activating it places a 7-hex cluster (a center plus its 6 neighbors, all
# empty and buildable) where at least one neighbor is adjacent to another of
# the player's settlements.
class CityHallTileTest < ActiveSupport::TestCase
  OTHER_SETTLEMENT = [ 1, 3 ].freeze
  CENTER = [ 1, 5 ].freeze
  CLUSTER = [ [ 1, 5 ], [ 1, 4 ], [ 1, 6 ], [ 0, 5 ], [ 0, 6 ], [ 2, 5 ], [ 2, 6 ] ].freeze

  test "picking up the tile grants a City Hall to the player's supply" do
    scenario = GameScenario.new(hands: { 0 => "G", 1 => "D" })
    spot = scenario.empty_hexes("G", 1).first
    tile_spot = scenario.neighbors(spot).first
    scenario.place_tile("CityHallTile", at: tile_spot, qty: 2)

    scenario.build_settlement(at: spot)

    assert_equal 1, scenario.city_halls_remaining(0)
  end

  test "is activatable only with City Hall supply, and finds a 7-hex cluster adjacent to another settlement" do
    scenario = GameScenario.new
    scenario.place_settlement(0, at: OTHER_SETTLEMENT)
    scenario.give_tile(0, "CityHallTile", from: [ 0, 0 ])

    assert_not_includes scenario.available_tile_actions(0), "CityHallTile"

    scenario.give_city_halls(0, 1)

    assert_includes scenario.available_tile_actions(0), "CityHallTile"

    scenario.activate_tile(:cityhall)
    destinations = scenario.buildable_cells

    assert_includes destinations, CENTER
  end

  test "placing the City Hall marks all 7 cluster hexes and consumes supply and the tile" do
    scenario = GameScenario.new
    scenario.place_settlement(0, at: OTHER_SETTLEMENT)
    scenario.give_tile(0, "CityHallTile", from: [ 0, 0 ])
    scenario.give_city_halls(0, 1)

    scenario.activate_tile(:cityhall)
    scenario.place_city_hall(at: CENTER)

    CLUSTER.each { |hex| assert scenario.city_hall_at?(hex), "expected city hall at #{hex.inspect}" }
    assert_equal 0, scenario.city_halls_remaining(0)
    assert_not_includes scenario.usable_tiles(0), "CityHallTile"
    assert_equal Game::MANDATORY_COUNT, scenario.mandatory_remaining
  end
end
