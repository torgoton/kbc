require "test_helper"

class Tiles::LighthouseTileTest < ActiveSupport::TestCase
  BoardStub = Struct.new(:terrain_map) do
    def terrain_at(row, col) = terrain_map.fetch([ row, col ], "")
  end

  def tile = Tiles::LighthouseTile.new(2)

  def all_water_board
    terrain = {}
    20.times { |r| 20.times { |c| terrain[[ r, c ]] = "W" } }
    BoardStub.new(terrain)
  end

  # --- placement ---

  test "places_meeple? is true" do
    assert tile.places_meeple?
  end

  test "on_pickup adds 1 ship to game_player supply" do
    gp = game_players(:chris)
    tile.on_pickup(game_player: gp)
    assert_equal 1, gp.ships_remaining
  end

  test "activatable? is true when ship in supply" do
    state = BoardState.new
    assert tile.activatable?(player_order: 0, board_contents: state, board: all_water_board, ship_supply: 1)
  end

  test "activatable? is true when ship already on board" do
    state = BoardState.new
    state.place_ship(5, 5, 0)
    assert tile.activatable?(player_order: 0, board_contents: state, board: all_water_board, ship_supply: 0)
  end

  test "activatable? is false when no supply and no ship on board" do
    state = BoardState.new
    assert_not tile.activatable?(player_order: 0, board_contents: state, board: all_water_board, ship_supply: 0)
  end

  test "valid_destinations (placement) returns empty when ship supply 0 and no ship on board" do
    state = BoardState.new
    assert_equal [], tile.valid_destinations(board_contents: state, board: all_water_board, player_order: 0, ship_supply: 0)
  end

  test "valid_destinations (placement) returns adjacent water hexes when own settlements present" do
    state = BoardState.new
    state.place_settlement(5, 5, 0)
    neighbors = state.neighbors(5, 5)
    destinations = tile.valid_destinations(board_contents: state, board: all_water_board, player_order: 0, ship_supply: 1)
    neighbors.each { |r, c| assert_includes destinations, [ r, c ] }
    assert_not_includes destinations, [ 0, 0 ]
  end

  test "valid_destinations (placement) falls back to all water when no adjacent water" do
    land_neighbors = BoardState.new.neighbors(5, 5)
    terrain = {}
    20.times { |r| 20.times { |c| terrain[[ r, c ]] = "W" } }
    land_neighbors.each { |(r, c)| terrain[[ r, c ]] = "G" }
    state = BoardState.new
    state.place_settlement(5, 5, 0)
    destinations = tile.valid_destinations(board_contents: state, board: BoardStub.new(terrain), player_order: 0, ship_supply: 1)
    assert_includes destinations, [ 0, 0 ]
  end

  test "valid_destinations (placement) excludes occupied water hexes" do
    state = BoardState.new
    state.place_settlement(5, 5, 0)
    state.place_settlement(5, 4, 1)
    destinations = tile.valid_destinations(board_contents: state, board: all_water_board, player_order: 0, ship_supply: 1)
    assert_not_includes destinations, [ 5, 4 ]
  end

  test "valid_destinations includes own ship hex when ship is on board" do
    state = BoardState.new
    state.place_ship(3, 3, 0)
    destinations = tile.valid_destinations(board_contents: state, board: all_water_board, player_order: 0, ship_supply: 0)
    assert_includes destinations, [ 3, 3 ]
  end

  # --- movement ---

  test "valid_destinations (move) returns empty when no adjacent empty water" do
    state = BoardState.new
    state.place_ship(1, 1, 0)
    all_land = {}
    20.times { |r| 20.times { |c| all_land[[ r, c ]] = "G" } }
    all_land[[ 1, 1 ]] = "W"
    destinations = tile.valid_destinations(
      from_row: 1, from_col: 1,
      board_contents: state, board: BoardStub.new(all_land), player_order: 0
    )
    assert_equal [], destinations
  end

  test "valid_destinations (move) returns reachable water hexes within 3 steps" do
    state = BoardState.new
    state.place_ship(10, 10, 0)
    dests = tile.valid_destinations(
      from_row: 10, from_col: 10,
      board_contents: state, board: all_water_board, player_order: 0
    )
    assert_includes dests, [ 10, 11 ]
    assert_includes dests, [ 10, 12 ]
    assert_includes dests, [ 10, 13 ]
    assert_not_includes dests, [ 10, 14 ]
    assert_not_includes dests, [ 10, 10 ]
  end

  test "valid_destinations (move) does not cross land hexes" do
    terrain = {}
    20.times { |r| 20.times { |c| terrain[[ r, c ]] = "G" } }
    (8..12).each { |c| terrain[[ 10, c ]] = "W" }
    terrain[[ 10, 15 ]] = "W"
    state = BoardState.new
    state.place_ship(10, 10, 0)
    dests = tile.valid_destinations(
      from_row: 10, from_col: 10,
      board_contents: state, board: BoardStub.new(terrain), player_order: 0
    )
    assert_not_includes dests, [ 10, 15 ]
  end

  test "valid_destinations (move) does not include occupied hexes" do
    state = BoardState.new
    state.place_ship(10, 10, 0)
    state.place_settlement(10, 11, 1)
    dests = tile.valid_destinations(
      from_row: 10, from_col: 10,
      board_contents: state, board: all_water_board, player_order: 0
    )
    assert_not_includes dests, [ 10, 11 ]
  end

  test "selectable_ships returns ship coords when ship can move" do
    state = BoardState.new
    state.place_ship(10, 10, 0)
    result = tile.selectable_ships(player_order: 0, board_contents: state, board: all_water_board)
    assert_includes result, [ 10, 10 ]
  end

  test "selectable_ships returns empty when ship has no move destinations" do
    state = BoardState.new
    state.place_ship(1, 1, 0)
    all_land = {}
    20.times { |r| 20.times { |c| all_land[[ r, c ]] = "G" } }
    all_land[[ 1, 1 ]] = "W"
    result = tile.selectable_ships(player_order: 0, board_contents: state, board: BoardStub.new(all_land))
    assert_equal [], result
  end
end
