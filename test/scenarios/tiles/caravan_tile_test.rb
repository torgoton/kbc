require "test_helper"

# CaravanTile grants one extra settlement move: relocate any one of the
# player's settlements as far as possible along a straight line (one of the
# 6 board directions), stopping at the last empty, buildable hex before an
# obstacle or off-board/non-buildable terrain.
class CaravanTileTest < ActiveSupport::TestCase
  START = [ 5, 6 ].freeze
  FAR_DESTINATION = [ 8, 8 ].freeze
  OBSTACLE = [ 7, 7 ].freeze
  SHORTENED_DESTINATION = [ 6, 7 ].freeze
  FULL_DESTINATIONS = [ [ 5, 4 ], [ 5, 12 ], [ 1, 4 ], [ 0, 9 ], [ 6, 6 ], FAR_DESTINATION ].to_set.freeze

  test "is activatable when a settlement has a straight-line move available" do
    scenario = GameScenario.new
    scenario.place_settlement(0, at: START)
    scenario.give_tile(0, "CaravanTile", from: [ 0, 0 ])

    assert_includes scenario.available_tile_actions(0), "CaravanTile"
  end

  test "restricts destinations to the farthest reachable hex on each line, stopping short of an obstacle" do
    scenario = GameScenario.new
    scenario.place_settlement(0, at: START)
    scenario.place_settlement(1, at: OBSTACLE)
    scenario.give_tile(0, "CaravanTile", from: [ 0, 0 ])

    scenario.activate_tile(:caravan)
    scenario.select_settlement(at: START)
    destinations = scenario.buildable_cells

    expected = (FULL_DESTINATIONS - [ FAR_DESTINATION ]) + [ SHORTENED_DESTINATION ]
    assert_equal expected, destinations.to_set
    destinations.each do |dest|
      assert_includes Tiles::Tile::BUILDABLE_TERRAIN, scenario.terrain_at(dest)
      assert_nil scenario.owner_at(dest)
    end
  end

  test "moves a settlement as far as possible along a straight line, vacating the source" do
    scenario = GameScenario.new
    scenario.place_settlement(0, at: START)
    scenario.give_tile(0, "CaravanTile", from: [ 0, 0 ])

    scenario.activate_tile(:caravan)
    scenario.select_settlement(at: START)
    destinations = scenario.buildable_cells

    assert_equal FULL_DESTINATIONS, destinations.to_set

    scenario.move_step(to: FAR_DESTINATION)

    assert_equal 0, scenario.owner_at(FAR_DESTINATION)
    assert_nil scenario.owner_at(START)
    assert_equal Game::MANDATORY_COUNT, scenario.mandatory_remaining
    assert_not_includes scenario.usable_tiles(0), "CaravanTile"
  end
end
