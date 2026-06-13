require "test_helper"

# BarracksTile lets the player place a warrior from supply (adjacent to an
# existing settlement if possible, otherwise anywhere on buildable terrain) or
# remove one of their own placed warriors back to supply, without consuming
# the mandatory build count.
class BarracksTileTest < ActiveSupport::TestCase
  SETTLEMENT = [ 1, 1 ].freeze
  ADJACENT_BUILDABLE = [ [ 1, 0 ], [ 0, 1 ], [ 0, 2 ], [ 2, 1 ] ].freeze

  test "places a warrior adjacent to an existing settlement when supply is available" do
    scenario = GameScenario.new
    scenario.place_settlement(0, at: SETTLEMENT)
    scenario.give_warriors(0, 2)
    scenario.give_tile(0, "BarracksTile", from: [ 0, 0 ])

    scenario.activate_tile(:barracks)
    destinations = scenario.buildable_cells
    assert destinations.any?
    destinations.each { |dest| assert_includes ADJACENT_BUILDABLE, dest }

    target = destinations.first
    scenario.move_meeple_step(to: target)

    assert_equal "warrior", scenario.meeple_at(target)
    assert_equal 0, scenario.owner_at(target)
    assert_equal 1, scenario.warriors_remaining(0)
    assert_equal Game::MANDATORY_COUNT, scenario.mandatory_remaining
    assert_not_includes scenario.usable_tiles(0), "BarracksTile"
  end

  test "places a warrior anywhere on buildable terrain when no settlement is adjacent to one" do
    scenario = GameScenario.new
    scenario.give_warriors(0, 1)
    scenario.give_tile(0, "BarracksTile", from: [ 0, 0 ])

    scenario.activate_tile(:barracks)
    target = scenario.buildable_cells.first
    assert_includes Tiles::Tile::BUILDABLE_TERRAIN, scenario.terrain_at(target)

    scenario.move_meeple_step(to: target)

    assert_equal "warrior", scenario.meeple_at(target)
    assert_equal 0, scenario.warriors_remaining(0)
  end

  test "removes one of the player's own placed warriors back to supply" do
    scenario = GameScenario.new
    warrior_spot = [ 5, 5 ]
    scenario.place_warrior(0, at: warrior_spot)
    scenario.give_tile(0, "BarracksTile", from: [ 0, 0 ])

    scenario.activate_tile(:barracks)
    scenario.remove_meeple(at: warrior_spot)

    assert_nil scenario.meeple_at(warrior_spot)
    assert_nil scenario.owner_at(warrior_spot)
    assert_equal 1, scenario.warriors_remaining(0)
    assert_not_includes scenario.usable_tiles(0), "BarracksTile"
  end

  test "is not activatable without warrior supply or placed warriors" do
    scenario = GameScenario.new
    scenario.give_tile(0, "BarracksTile", from: [ 0, 0 ])

    assert_not_includes scenario.available_tile_actions(0), "BarracksTile"
  end
end
