require "test_helper"

# The Island is a separate board, but settlements move between it and the main map like any other
# (not adjacent, so a played-terrain mover falls back to "anywhere on that terrain").
class IslandMovementTest < ActiveSupport::TestCase
  def island_scenario
    GameScenario.new(hands: { 0 => "G" }).tap do |scenario|
      scenario.game.update!(decree: { "name" => "island", "map" => 0 })
      scenario.give_tile(0, "BarnTile", from: [ 0, 0 ])
    end
  end

  test "Barn moves a settlement from the main map onto the Island" do
    scenario = island_scenario
    from = [ 10, 10 ]
    scenario.place_settlement(0, at: from)

    scenario.activate_tile(:barn)
    scenario.select_settlement(at: from)
    island_hex = scenario.buildable_cells.find { |r, _| r >= Boards::Island::ROW }
    assert island_hex, "Island grass should be a destination"
    assert_equal "G", scenario.terrain_at(island_hex)

    scenario.move_step(to: island_hex)

    assert_equal 0, scenario.owner_at(island_hex)
    assert_nil scenario.owner_at(from)
  end

  test "Barn moves a settlement from the Island back to the main map" do
    scenario = island_scenario
    from = [ 21, 1 ]
    scenario.place_settlement(0, at: from)

    scenario.activate_tile(:barn)
    scenario.select_settlement(at: from)
    main_hex = scenario.buildable_cells.find { |r, _| r < Boards::Island::ROW }
    assert main_hex, "main-map grass should be a destination"

    scenario.move_step(to: main_hex)

    assert_equal 0, scenario.owner_at(main_hex)
    assert_nil scenario.owner_at(from)
  end

  test "a mandatory build can also go on the Island" do
    scenario = island_scenario
    island_hex = scenario.buildable_cells.find { |r, _| r >= Boards::Island::ROW }
    assert island_hex

    scenario.build_settlement(at: island_hex)

    assert_equal 0, scenario.owner_at(island_hex)
  end
end
