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

  test "placing the City Hall round-trips through undo" do
    scenario = GameScenario.new
    scenario.place_settlement(0, at: OTHER_SETTLEMENT)
    scenario.give_tile(0, "CityHallTile", from: [ 0, 0 ])
    scenario.give_city_halls(0, 1)
    scenario.activate_tile(:cityhall)

    assert_undo_round_trip(scenario) { scenario.place_city_hall(at: CENTER) }
  end

  test "the tile is spent permanently: it cannot be used again on a later turn" do
    scenario = GameScenario.new
    scenario.place_settlement(0, at: OTHER_SETTLEMENT)
    scenario.give_tile(0, "CityHallTile", from: [ 0, 0 ])
    scenario.give_city_halls(0, 1)

    scenario.activate_tile(:cityhall)
    scenario.place_city_hall(at: CENTER)

    # End of turn resets ordinary used tiles to usable; a City Hall tile is
    # permanently spent and stays unavailable when play returns to the player.
    scenario.set_mandatory(0)
    scenario.end_turn
    scenario.set_mandatory(0)
    scenario.end_turn

    assert_not_includes scenario.usable_tiles(0), "CityHallTile"
  end

  test "placing the City Hall collects a tile it lands adjacent to" do
    scenario = GameScenario.new
    scenario.place_settlement(0, at: OTHER_SETTLEMENT)
    scenario.give_tile(0, "CityHallTile", from: [ 0, 0 ])
    scenario.give_city_halls(0, 1)
    tile_spot = [ 1, 7 ] # sole outside neighbor of cluster hex [1, 6]
    scenario.place_tile("OasisTile", at: tile_spot, qty: 2)

    scenario.activate_tile(:cityhall)
    scenario.place_city_hall(at: CENTER)

    assert scenario.holds_tile?(0, klass: "OasisTile", from: tile_spot)
    assert_equal 1, scenario.tile_qty(tile_spot)
  end

  test "placing the City Hall adjacent to 2 opponent settlements scores 2 Ambassadors points" do
    scenario = GameScenario.new(goals: [ "ambassadors" ])
    scenario.place_settlement(0, at: OTHER_SETTLEMENT)
    scenario.give_tile(0, "CityHallTile", from: [ 0, 0 ])
    scenario.give_city_halls(0, 1)
    # [1, 7] and [3, 4] are each the sole outside neighbor of a distinct
    # cluster hex ([1, 6] and [2, 5]), so each scores independently.
    scenario.place_settlement(1, at: [ 1, 7 ])
    scenario.place_settlement(1, at: [ 3, 4 ])

    scenario.activate_tile(:cityhall)
    scenario.place_city_hall(at: CENTER)

    assert_equal 2, scenario.score_for("ambassadors", 0)
  end

  test "placing the City Hall away from opponent settlements scores no Ambassadors points" do
    scenario = GameScenario.new(goals: [ "ambassadors" ])
    scenario.place_settlement(0, at: OTHER_SETTLEMENT)
    scenario.give_tile(0, "CityHallTile", from: [ 0, 0 ])
    scenario.give_city_halls(0, 1)

    scenario.activate_tile(:cityhall)
    scenario.place_city_hall(at: CENTER)

    assert_equal 0, scenario.score_for("ambassadors", 0)
  end

  test "placing the City Hall scores the minimum 2 Shepherds points (only the center hex)" do
    scenario = GameScenario.new(goals: [ "shepherds" ])
    center = [ 3, 4 ]
    # Own settlement adjacent to ring hex [3, 3], on non-matching terrain (W)
    # so it satisfies the placement's adjacency rule without blocking any
    # ring hex's same-terrain emptiness check.
    scenario.place_settlement(0, at: [ 4, 3 ])
    scenario.give_tile(0, "CityHallTile", from: [ 0, 0 ])
    scenario.give_city_halls(0, 1)

    scenario.activate_tile(:cityhall)
    scenario.place_city_hall(at: center)

    assert_equal 2, scenario.score_for("shepherds", 0)
  end

  test "placing the City Hall scores 8 Shepherds points (center plus 3 blocked ring hexes)" do
    scenario = GameScenario.new(goals: [ "shepherds" ])
    center = [ 3, 4 ]
    scenario.place_settlement(0, at: [ 4, 3 ])
    scenario.give_tile(0, "CityHallTile", from: [ 0, 0 ])
    scenario.give_city_halls(0, 1)
    # Each fill removes the last empty same-terrain neighbor for one ring
    # hex: [2, 3] -> [3, 3] (Farm), [2, 6] -> [3, 5] (Terrain), [5, 4] -> [4, 4] (Grass).
    [ [ 2, 3 ], [ 2, 6 ], [ 5, 4 ] ].each { |hex| scenario.place_settlement(1, at: hex) }

    scenario.activate_tile(:cityhall)
    scenario.place_city_hall(at: center)

    assert_equal 8, scenario.score_for("shepherds", 0)
  end

  test "placing the City Hall scores the maximum 14 Shepherds points (all 7 hexes)" do
    scenario = GameScenario.new(goals: [ "shepherds" ])
    center = [ 3, 4 ]
    scenario.place_settlement(0, at: [ 4, 3 ])
    scenario.give_tile(0, "CityHallTile", from: [ 0, 0 ])
    scenario.give_city_halls(0, 1)
    # Every same-terrain outside neighbor of every ring hex is filled, so
    # none has an empty same-terrain neighbor left.
    [ [ 2, 3 ], [ 1, 3 ], [ 1, 4 ], [ 2, 6 ], [ 1, 5 ], [ 5, 4 ], [ 4, 6 ], [ 5, 5 ] ].each do |hex|
      scenario.place_settlement(1, at: hex)
    end

    scenario.activate_tile(:cityhall)
    scenario.place_city_hall(at: center)

    assert_equal 14, scenario.score_for("shepherds", 0)
  end

  test "an opponent's Sword cannot remove a City Hall hex" do
    scenario = GameScenario.new
    scenario.place_settlement(0, at: OTHER_SETTLEMENT)
    scenario.give_tile(0, "CityHallTile", from: [ 0, 0 ])
    scenario.give_city_halls(0, 1)
    scenario.activate_tile(:cityhall)
    scenario.place_city_hall(at: CENTER)

    scenario.make_current(1)
    scenario.give_tile(1, "SwordTile", from: [ 0, 0 ])
    scenario.activate_tile(:sword)

    assert_includes scenario.buildable_cells, OTHER_SETTLEMENT # the plain settlement is a target
    assert_not_includes scenario.buildable_cells, CENTER       # a City Hall hex is not
    assert_raises(GameScenario::IllegalMove) { scenario.remove_settlement(at: CENTER) }
    assert scenario.city_hall_at?(CENTER)
  end
end
