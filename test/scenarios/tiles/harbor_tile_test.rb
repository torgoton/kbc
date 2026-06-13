require "test_helper"

# HarborTile grants one extra settlement move: relocate any one of the
# player's settlements to a water space - adjacent to another of their
# settlements if possible, otherwise anywhere on water.
class HarborTileTest < ActiveSupport::TestCase
  test "moves a settlement to a water space adjacent to another of the player's settlements" do
    scenario = GameScenario.new
    moving_spot = [ 10, 10 ]
    stationary_spot = [ 1, 1 ]
    destination = [ 1, 2 ]
    scenario.place_settlement(0, at: moving_spot)
    scenario.place_settlement(0, at: stationary_spot)
    scenario.give_tile(0, "HarborTile", from: [ 0, 0 ])

    scenario.activate_tile(:harbor)
    scenario.select_settlement(at: moving_spot)
    destinations = scenario.buildable_cells

    assert_includes destinations, destination
    destinations.each do |dest|
      assert_equal "W", scenario.terrain_at(dest)
      assert_includes scenario.neighbors(stationary_spot), dest
    end

    scenario.move_step(to: destination)

    assert_equal 0, scenario.owner_at(destination)
    assert_nil scenario.owner_at(moving_spot)
    assert_equal 0, scenario.owner_at(stationary_spot)
    assert_equal Game::MANDATORY_COUNT, scenario.mandatory_remaining
    assert_not_includes scenario.usable_tiles(0), "HarborTile"
  end

  test "moves anywhere on water when no other settlement is adjacent to one" do
    scenario = GameScenario.new
    moving_spot = [ 10, 10 ]
    scenario.place_settlement(0, at: moving_spot)
    scenario.give_tile(0, "HarborTile", from: [ 0, 0 ])

    scenario.activate_tile(:harbor)
    scenario.select_settlement(at: moving_spot)
    destinations = scenario.buildable_cells

    assert destinations.any?
    destinations.each { |dest| assert_equal "W", scenario.terrain_at(dest) }

    destination = destinations.first
    scenario.move_step(to: destination)

    assert_equal 0, scenario.owner_at(destination)
    assert_nil scenario.owner_at(moving_spot)
  end
end
