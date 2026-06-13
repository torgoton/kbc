require "test_helper"

# TavernTile grants one extra settlement build at either end of a line of at
# least 3 of the player's own settlements (any of the three board axes),
# constrained to spaces eligible for building, without consuming the
# mandatory build count.
class TavernTileTest < ActiveSupport::TestCase
  # Row 5 of the fixed board: cols 6,7,8 are C,C,D (all buildable); the line
  # ends at col 5 (G) and col 9 (C), both empty and buildable.
  LINE = [ [ 5, 6 ], [ 5, 7 ], [ 5, 8 ] ].freeze
  ENDS = [ [ 5, 5 ], [ 5, 9 ] ].freeze

  test "builds an extra settlement at the end of a 3-settlement line" do
    scenario = GameScenario.new
    LINE.each { |spot| scenario.place_settlement(0, at: spot) }
    scenario.give_tile(0, "TavernTile", from: [ 0, 0 ])

    scenario.activate_tile(:tavern)
    scenario.build_settlement(at: ENDS.last)

    assert_equal 0, scenario.owner_at(ENDS.last)
    assert_equal Game::SETTLEMENTS_PER_PLAYER - 1, scenario.settlements_remaining(0)
    assert_equal Game::MANDATORY_COUNT, scenario.mandatory_remaining
    assert_not_includes scenario.usable_tiles(0), "TavernTile"
  end

  test "restricts build destinations to the ends of the line" do
    scenario = GameScenario.new
    LINE.each { |spot| scenario.place_settlement(0, at: spot) }
    scenario.give_tile(0, "TavernTile", from: [ 0, 0 ])

    scenario.activate_tile(:tavern)
    destinations = scenario.buildable_cells

    assert_equal ENDS.to_set, destinations.to_set
  end

  test "rejects a build that is not at an end of the line" do
    scenario = GameScenario.new
    LINE.each { |spot| scenario.place_settlement(0, at: spot) }
    scenario.give_tile(0, "TavernTile", from: [ 0, 0 ])
    elsewhere = scenario.empty_hexes("F", 1).first

    scenario.activate_tile(:tavern)

    assert_raises(GameScenario::IllegalMove) { scenario.build_settlement(at: elsewhere) }
  end

  test "is not activatable without a line of at least 3 settlements" do
    scenario = GameScenario.new
    LINE.first(2).each { |spot| scenario.place_settlement(0, at: spot) }
    scenario.give_tile(0, "TavernTile", from: [ 0, 0 ])

    assert_not_includes scenario.available_tile_actions(0), "TavernTile"
  end
end
