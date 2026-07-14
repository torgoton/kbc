require "test_helper"

# BarnTile grants one extra settlement move: relocate any one of the player's
# settlements to a space of the same terrain as their played (hand) terrain
# card - adjacent to another of their settlements if possible, otherwise
# anywhere on that terrain.
class BarnTileTest < ActiveSupport::TestCase
  test "moves a settlement to the played terrain, adjacent to another of the player's settlements" do
    scenario = GameScenario.new(hands: { 0 => "G" })
    moving_spot = [ 10, 10 ]
    stationary_spot = [ 0, 8 ]
    destination = [ 0, 9 ]
    scenario.place_settlement(0, at: moving_spot)
    scenario.place_settlement(0, at: stationary_spot)
    scenario.give_tile(0, "BarnTile", from: [ 0, 0 ])

    scenario.activate_tile(:barn)
    scenario.select_settlement(at: moving_spot)
    destinations = scenario.buildable_cells

    assert_includes destinations, destination
    destinations.each do |dest|
      assert_equal "G", scenario.terrain_at(dest)
      assert_includes scenario.neighbors(stationary_spot), dest
    end

    scenario.move_step(to: destination)

    assert_equal 0, scenario.owner_at(destination)
    assert_nil scenario.owner_at(moving_spot)
    assert_equal 0, scenario.owner_at(stationary_spot)
    assert_equal Game::MANDATORY_COUNT, scenario.mandatory_remaining
    assert_not_includes scenario.usable_tiles(0), "BarnTile"
  end

  test "moves anywhere on the played terrain when no other settlement is adjacent to one" do
    scenario = GameScenario.new(hands: { 0 => "G" })
    moving_spot = [ 10, 10 ]
    scenario.place_settlement(0, at: moving_spot)
    scenario.give_tile(0, "BarnTile", from: [ 0, 0 ])

    scenario.activate_tile(:barn)
    scenario.select_settlement(at: moving_spot)
    destinations = scenario.buildable_cells

    assert destinations.any?
    destinations.each { |dest| assert_equal "G", scenario.terrain_at(dest) }

    destination = destinations.first
    scenario.move_step(to: destination)

    assert_equal 0, scenario.owner_at(destination)
    assert_nil scenario.owner_at(moving_spot)
  end

  test "limits moves to the already-locked played terrain when the hand still holds two cards" do
    scenario = GameScenario.new(hands: { 0 => %w[G T] })
    moving_spot = [ 10, 10 ]
    scenario.place_settlement(0, at: moving_spot)
    scenario.give_tile(0, "BarnTile", from: [ 0, 0 ])
    scenario.set_mandatory(1)

    build_spot = scenario.buildable_cells.find { |spot| scenario.terrain_at(spot) == "G" }
    scenario.build_settlement(at: build_spot)

    scenario.activate_tile(:barn)
    scenario.select_settlement(at: moving_spot)
    destinations = scenario.buildable_cells

    assert destinations.any?
    destinations.each { |dest| assert_equal "G", scenario.terrain_at(dest) }
  end

  test "activating before the mandatory build locks the terrain for the rest of the turn" do
    scenario = GameScenario.new(hands: { 0 => %w[G T] })
    moving_spot = [ 10, 10 ]
    scenario.place_settlement(0, at: moving_spot)
    scenario.give_tile(0, "BarnTile", from: [ 0, 0 ])

    scenario.activate_tile(:barn)
    scenario.select_settlement(at: moving_spot)
    destination = scenario.buildable_cells.find { |spot| scenario.terrain_at(spot) == "G" }
    scenario.move_step(to: destination)

    mandatory_destinations = scenario.buildable_cells
    assert mandatory_destinations.any?
    mandatory_destinations.each { |dest| assert_equal "G", scenario.terrain_at(dest) }
  end
end
