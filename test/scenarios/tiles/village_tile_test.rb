require "test_helper"

# VillageTile grants one extra settlement build on an eligible space adjacent
# to at least 3 of the player's own settlements, without consuming the
# mandatory build count.
class VillageTileTest < ActiveSupport::TestCase
  TARGET = [ 0, 1 ].freeze
  NEIGHBORS = [ [ 0, 0 ], [ 0, 2 ], [ 1, 0 ], [ 1, 1 ] ].freeze

  test "builds an extra settlement adjacent to 3 of the player's settlements" do
    scenario = GameScenario.new
    NEIGHBORS.first(3).each { |spot| scenario.place_settlement(0, at: spot) }
    scenario.give_tile(0, "VillageTile", from: [ 0, 0 ])

    scenario.activate_tile(:village)
    destinations = scenario.buildable_cells

    assert_includes destinations, TARGET

    scenario.build_settlement(at: TARGET)

    assert_equal 0, scenario.owner_at(TARGET)
    assert_equal Game::SETTLEMENTS_PER_PLAYER - 1, scenario.settlements_remaining(0)
    assert_equal Game::MANDATORY_COUNT, scenario.mandatory_remaining
    assert_not_includes scenario.usable_tiles(0), "VillageTile"
  end

  test "rejects a build adjacent to fewer than 3 settlements" do
    scenario = GameScenario.new
    NEIGHBORS.first(2).each { |spot| scenario.place_settlement(0, at: spot) }
    scenario.give_tile(0, "VillageTile", from: [ 0, 0 ])

    scenario.activate_tile(:village)

    assert_raises(GameScenario::IllegalMove) { scenario.build_settlement(at: TARGET) }
  end

  test "is not activatable without a space adjacent to 3 settlements" do
    scenario = GameScenario.new
    NEIGHBORS.first(2).each { |spot| scenario.place_settlement(0, at: spot) }
    scenario.give_tile(0, "VillageTile", from: [ 0, 0 ])

    assert_not_includes scenario.available_tile_actions(0), "VillageTile"
  end
end
