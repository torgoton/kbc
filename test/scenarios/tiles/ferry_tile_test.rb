require "test_helper"

# Ferry decree: move a settlement touching the ferry's body of water to any empty buildable hex
# touching that same water. Permanent tile, once per turn.
class FerryTileTest < ActiveSupport::TestCase
  def ferry_scenario
    scenario = GameScenario.new
    game = scenario.game
    game.instantiate
    ferry = BoardState.center_of(game.board_contents.water_bodies.max_by(&:size))
    game.update!(decree: { "name" => "ferry", "hex" => ferry })
    game.board = nil
    scenario.give_tile(0, "FerryTile", from: [ 0, 0 ])
    scenario
  end

  def shore_cells(scenario)
    scenario.game.instantiate
    scenario.game.board_contents.ferry_shore.select { |cell| Tiles::Tile::BUILDABLE_TERRAIN.include?(scenario.terrain_at(cell)) }
  end

  test "moves a shore settlement to another shore hex of the same water" do
    scenario = ferry_scenario
    from, to = shore_cells(scenario).first(2)
    scenario.place_settlement(0, at: from)

    scenario.activate_tile(:ferry)
    scenario.select_settlement(at: from)
    destinations = scenario.buildable_cells
    assert_includes destinations, to
    assert_equal (shore_cells(scenario) - [ from ]).to_set, destinations.to_set

    scenario.move_step(to:)
    assert_equal 0, scenario.owner_at(to)
    assert_nil scenario.owner_at(from)
    assert_equal Game::MANDATORY_COUNT, scenario.mandatory_remaining
    assert_not_includes scenario.usable_tiles(0), "FerryTile"
  end

  test "is available to a shore settlement" do
    scenario = ferry_scenario
    scenario.place_settlement(0, at: shore_cells(scenario).first)
    assert_includes scenario.available_tile_actions(0), "FerryTile"
  end

  test "a settlement away from the ferry's water cannot be moved" do
    scenario = ferry_scenario
    shore = shore_cells(scenario)
    inland = (0..19).flat_map { |r| (0..19).map { |c| [ r, c ] } }.find do |cell|
      Tiles::Tile::BUILDABLE_TERRAIN.include?(scenario.terrain_at(cell)) && !scenario.game.board_contents.ferry_shore.include?(cell)
    end
    scenario.place_settlement(0, at: inland)
    assert_not_includes scenario.available_tile_actions(0), "FerryTile"
    assert shore.any?
  end

  test "City Hall hexes cannot be ferried" do
    scenario = ferry_scenario
    scenario.place_city_hall_hex(0, at: shore_cells(scenario).first)
    assert_not_includes scenario.available_tile_actions(0), "FerryTile"
  end

  test "occupied shore hexes are not destinations" do
    scenario = ferry_scenario
    from, blocked = shore_cells(scenario).first(2)
    scenario.place_settlement(0, at: from)
    scenario.place_settlement(1, at: blocked)
    scenario.activate_tile(:ferry)
    scenario.select_settlement(at: from)
    assert_not_includes scenario.buildable_cells, blocked
  end
end
