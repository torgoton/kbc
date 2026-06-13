require "test_helper"

# QuarryTile grants 1 or 2 stone walls on empty hexes of the played terrain
# card, adjacent to the player's settlements.
class QuarryTileTest < ActiveSupport::TestCase
  SETTLEMENT = [ 5, 6 ].freeze
  WALL_SPOTS = [ [ 5, 5 ], [ 4, 6 ], [ 4, 7 ] ].freeze

  test "is activatable when an empty hex of the played terrain is adjacent to a settlement" do
    scenario = GameScenario.new(hands: { 0 => "G" })
    scenario.place_settlement(0, at: SETTLEMENT)
    scenario.give_tile(0, "QuarryTile", from: [ 0, 0 ])

    assert_includes scenario.available_tile_actions(0), "QuarryTile"
  end

  test "restricts wall placement to empty hexes of the played terrain adjacent to a settlement" do
    scenario = GameScenario.new(hands: { 0 => "G" })
    scenario.place_settlement(0, at: SETTLEMENT)
    scenario.give_tile(0, "QuarryTile", from: [ 0, 0 ])

    scenario.activate_tile(:quarry)
    destinations = scenario.buildable_cells

    assert_equal WALL_SPOTS.to_set, destinations.to_set
    destinations.each do |dest|
      assert_equal "G", scenario.terrain_at(dest)
      assert_includes scenario.neighbors(SETTLEMENT), dest
    end
  end

  test "places up to 2 stone walls, consuming the supply and the tile" do
    scenario = GameScenario.new(hands: { 0 => "G" })
    scenario.place_settlement(0, at: SETTLEMENT)
    scenario.give_tile(0, "QuarryTile", from: [ 0, 0 ])
    initial_walls = scenario.stone_walls

    scenario.activate_tile(:quarry)
    scenario.place_wall(at: WALL_SPOTS[0])

    assert scenario.wall_at?(WALL_SPOTS[0])
    assert_equal initial_walls - 1, scenario.stone_walls
    assert_includes scenario.usable_tiles(0), "QuarryTile"

    scenario.place_wall(at: WALL_SPOTS[1])

    assert scenario.wall_at?(WALL_SPOTS[1])
    assert_equal initial_walls - 2, scenario.stone_walls
    assert_equal Game::MANDATORY_COUNT, scenario.mandatory_remaining
    assert_not_includes scenario.usable_tiles(0), "QuarryTile"
  end
end
