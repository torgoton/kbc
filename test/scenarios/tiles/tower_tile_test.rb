require "test_helper"

# TowerTile grants one extra settlement build on any eligible terrain at the
# edge of the board - adjacent to an existing settlement if possible,
# otherwise anywhere on the edge - without consuming the mandatory build
# count.
class TowerTileTest < ActiveSupport::TestCase
  test "builds an extra settlement at the edge adjacent to an existing settlement" do
    scenario = GameScenario.new
    scenario.place_settlement(0, at: [ 1, 1 ])
    scenario.give_tile(0, "TowerTile", from: [ 0, 0 ])

    scenario.activate_tile(:tower)
    destinations = scenario.buildable_cells
    target = [ 1, 0 ]

    assert_includes destinations, target
    destinations.each do |r, c|
      assert (r == 0 || r == 19 || c == 0 || c == 19), "[#{r}, #{c}] is not on the edge of the board"
      assert_includes scenario.neighbors([ 1, 1 ]), [ r, c ]
    end

    scenario.build_settlement(at: target)

    assert_equal 0, scenario.owner_at(target)
    assert_equal Game::SETTLEMENTS_PER_PLAYER - 1, scenario.settlements_remaining(0)
    assert_equal Game::MANDATORY_COUNT, scenario.mandatory_remaining
    assert_not_includes scenario.usable_tiles(0), "TowerTile"
  end

  test "builds anywhere on the edge when no settlement is adjacent to one" do
    scenario = GameScenario.new
    scenario.give_tile(0, "TowerTile", from: [ 0, 0 ])

    scenario.activate_tile(:tower)
    destinations = scenario.buildable_cells

    assert destinations.any?
    destinations.each do |r, c|
      assert (r == 0 || r == 19 || c == 0 || c == 19), "[#{r}, #{c}] is not on the edge of the board"
    end

    scenario.build_settlement(at: [ 0, 0 ])

    assert_equal 0, scenario.owner_at([ 0, 0 ])
    assert_equal Game::SETTLEMENTS_PER_PLAYER - 1, scenario.settlements_remaining(0)
  end

  test "rejects a build away from the edge of the board" do
    scenario = GameScenario.new
    scenario.give_tile(0, "TowerTile", from: [ 0, 0 ])
    interior = [ 1, 1 ]

    scenario.activate_tile(:tower)

    assert_raises(GameScenario::IllegalMove) { scenario.build_settlement(at: interior) }
  end
end
