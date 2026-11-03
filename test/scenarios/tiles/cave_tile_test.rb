require "test_helper"

# Caves decree: move a settlement next to any Cave to any empty buildable hex next to any Cave.
class CaveTileTest < ActiveSupport::TestCase
  def cave_scenario
    scenario = GameScenario.new
    game = scenario.game
    game.instantiate
    mountains = BoardState::MAIN_CELLS.select { |c| scenario.terrain_at(c) == "M" }
    caves = [ mountains.first, mountains.last ]
    game.update!(decree: { "name" => "caves", "hexes" => caves })
    game.board = nil
    scenario.give_tile(0, "CaveTile", from: [ 0, 0 ])
    scenario
  end

  def shore_cells(scenario)
    scenario.game.instantiate
    scenario.game.board_contents.cave_shore.select { |cell| Tiles::Tile::BUILDABLE_TERRAIN.include?(scenario.terrain_at(cell)) }
  end

  test "moves a settlement from beside one cave to beside another" do
    scenario = cave_scenario
    caves = scenario.game.cave_hexes
    shore = shore_cells(scenario)
    from = shore.find { |c| BoardState.distance(c, caves.first) == 1 }
    to = shore.find { |c| BoardState.distance(c, caves.last) == 1 }
    scenario.place_settlement(0, at: from)

    scenario.activate_tile(:cave)
    scenario.select_settlement(at: from)
    assert_equal (shore - [ from ]).to_set, scenario.buildable_cells.to_set

    scenario.move_step(to:)
    assert_equal 0, scenario.owner_at(to)
    assert_nil scenario.owner_at(from)
    assert_equal Game::MANDATORY_COUNT, scenario.mandatory_remaining
  end

  test "is available only to a settlement next to a cave, never a City Hall hex" do
    scenario = cave_scenario
    shore = shore_cells(scenario)
    inland = BoardState::MAIN_CELLS.find do |cell|
      Tiles::Tile::BUILDABLE_TERRAIN.include?(scenario.terrain_at(cell)) && !scenario.game.board_contents.cave_shore.include?(cell)
    end
    scenario.place_settlement(0, at: inland)
    assert_not_includes scenario.available_tile_actions(0), "CaveTile"
    scenario.place_city_hall_hex(0, at: shore.first)
    assert_not_includes scenario.available_tile_actions(0), "CaveTile"
    scenario.place_settlement(0, at: shore.last)
    assert_includes scenario.available_tile_actions(0), "CaveTile"
  end
end
