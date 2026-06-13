require "test_helper"

# PaddockTile grants one extra settlement move: jump exactly 2 hexes in a
# straight line (any of the 6 board directions) to an eligible empty,
# buildable space, regardless of what occupies the hex jumped over.
class PaddockTileTest < ActiveSupport::TestCase
  START = [ 5, 6 ].freeze
  OCCUPIED_BETWEEN = [ 5, 7 ].freeze
  JUMP_DESTINATIONS = [ [ 5, 4 ], [ 5, 8 ], [ 3, 5 ], [ 3, 7 ], [ 7, 7 ] ].freeze

  test "is activatable when a settlement has a 2-hex straight-line jump available" do
    scenario = GameScenario.new
    scenario.place_settlement(0, at: START)
    scenario.give_tile(0, "PaddockTile", from: [ 0, 0 ])

    assert_includes scenario.available_tile_actions(0), "PaddockTile"
  end

  test "restricts destinations to 2-hex straight-line jumps onto eligible empty spaces" do
    scenario = GameScenario.new
    scenario.place_settlement(0, at: START)
    scenario.place_settlement(1, at: OCCUPIED_BETWEEN)
    scenario.give_tile(0, "PaddockTile", from: [ 0, 0 ])

    scenario.activate_tile(:paddock)
    scenario.select_settlement(at: START)
    destinations = scenario.buildable_cells

    assert_equal JUMP_DESTINATIONS.to_set, destinations.to_set
    destinations.each do |dest|
      assert_includes Tiles::Tile::BUILDABLE_TERRAIN, scenario.terrain_at(dest)
      assert_nil scenario.owner_at(dest)
    end
  end

  test "jumps a settlement 2 hexes in a straight line over an occupied hex, vacating the source" do
    scenario = GameScenario.new
    scenario.place_settlement(0, at: START)
    scenario.place_settlement(1, at: OCCUPIED_BETWEEN)
    scenario.give_tile(0, "PaddockTile", from: [ 0, 0 ])
    destination = [ 5, 8 ]

    scenario.activate_tile(:paddock)
    scenario.select_settlement(at: START)
    scenario.move_step(to: destination)

    assert_equal 0, scenario.owner_at(destination)
    assert_nil scenario.owner_at(START)
    assert_equal 1, scenario.owner_at(OCCUPIED_BETWEEN)
    assert_equal Game::MANDATORY_COUNT, scenario.mandatory_remaining
    assert_not_includes scenario.usable_tiles(0), "PaddockTile"
  end
end
