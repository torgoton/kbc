require "test_helper"

class Tiles::WagonTileTest < ActiveSupport::TestCase
  BoardStub = Struct.new(:terrain_map) do
    def terrain_at(row, col) = terrain_map.fetch([ row, col ], "")
  end

  SUITABLE = Tiles::Tile::BUILDABLE_TERRAIN + [ "M" ]

  def tile = Tiles::WagonTile.new(2)

  def all_grass_board
    terrain = {}
    20.times { |r| 20.times { |c| terrain[[ r, c ]] = "G" } }
    BoardStub.new(terrain)
  end

  def all_water_board
    terrain = {}
    20.times { |r| 20.times { |c| terrain[[ r, c ]] = "W" } }
    BoardStub.new(terrain)
  end

  # --- basics ---

  test "places_meeple? is true" do
    assert tile.places_meeple?
  end

  test "meeple_kind is wagon" do
    assert_equal "wagon", tile.meeple_kind
  end

  test "on_pickup adds 1 wagon to game_player supply" do
    gp = game_players(:chris)
    tile.on_pickup(game_player: gp)
    assert_equal 1, gp.wagons_remaining
  end

  # --- activatable? ---

  test "activatable? is true when wagon in supply" do
    state = BoardState.new
    assert tile.activatable?(player_order: 0, board_contents: state, board: all_grass_board, supply: { "wagon" => 1 })
  end

  test "activatable? is true when wagon already on board" do
    state = BoardState.new
    state.place_wagon(5, 5, 0)
    assert tile.activatable?(player_order: 0, board_contents: state, board: all_grass_board, supply: { "wagon" => 0 })
  end

  test "activatable? is false when no supply and no wagon on board" do
    state = BoardState.new
    assert_not tile.activatable?(player_order: 0, board_contents: state, board: all_grass_board, supply: { "wagon" => 0 })
  end

  # --- valid_destinations (placement) ---

  test "valid_destinations (placement) returns empty when wagon supply 0 and no wagon on board" do
    state = BoardState.new
    assert_equal [], tile.valid_destinations(board_contents: state, board: all_grass_board, player_order: 0, supply: { "wagon" => 0 })
  end

  test "valid_destinations (placement) returns adjacent suitable hexes when own settlements present" do
    state = BoardState.new
    state.place_settlement(5, 5, 0)
    neighbors = state.neighbors(5, 5)
    destinations = tile.valid_destinations(board_contents: state, board: all_grass_board, player_order: 0, supply: { "wagon" => 1 })
    neighbors.each { |r, c| assert_includes destinations, [ r, c ] }
    assert_not_includes destinations, [ 0, 0 ]
  end

  test "valid_destinations (placement) falls back to all suitable hexes when no adjacent suitable" do
    land_neighbors = BoardState.new.neighbors(5, 5)
    terrain = {}
    20.times { |r| 20.times { |c| terrain[[ r, c ]] = "G" } }
    land_neighbors.each { |(r, c)| terrain[[ r, c ]] = "W" }
    state = BoardState.new
    state.place_settlement(5, 5, 0)
    destinations = tile.valid_destinations(board_contents: state, board: BoardStub.new(terrain), player_order: 0, supply: { "wagon" => 1 })
    assert_includes destinations, [ 0, 0 ]
  end

  test "valid_destinations (placement) excludes occupied hexes" do
    state = BoardState.new
    state.place_settlement(5, 5, 0)
    state.place_settlement(5, 4, 1)
    destinations = tile.valid_destinations(board_contents: state, board: all_grass_board, player_order: 0, supply: { "wagon" => 1 })
    assert_not_includes destinations, [ 5, 4 ]
  end

  test "valid_destinations (placement) includes own wagon hex when wagon is on board" do
    state = BoardState.new
    state.place_wagon(3, 3, 0)
    destinations = tile.valid_destinations(board_contents: state, board: all_grass_board, player_order: 0, supply: { "wagon" => 0 })
    assert_includes destinations, [ 3, 3 ]
  end

  test "valid_destinations (placement) includes mountain hexes" do
    terrain = {}
    20.times { |r| 20.times { |c| terrain[[ r, c ]] = "M" } }
    state = BoardState.new
    state.place_settlement(5, 5, 0)
    destinations = tile.valid_destinations(board_contents: state, board: BoardStub.new(terrain), player_order: 0, supply: { "wagon" => 1 })
    state.neighbors(5, 5).each { |r, c| assert_includes destinations, [ r, c ] }
  end

  test "valid_destinations (placement) excludes water hexes" do
    state = BoardState.new
    state.place_settlement(5, 5, 0)
    destinations = tile.valid_destinations(board_contents: state, board: all_water_board, player_order: 0, supply: { "wagon" => 1 })
    assert_equal [], destinations
  end

  # --- valid_destinations (movement) ---

  test "valid_destinations (move) returns empty when surrounded by water" do
    state = BoardState.new
    state.place_wagon(5, 5, 0)
    destinations = tile.valid_destinations(
      from_row: 5, from_col: 5,
      board_contents: state, board: all_water_board, player_order: 0
    )
    assert_equal [], destinations
  end

  test "valid_destinations (move) reaches up to 3 steps through suitable terrain" do
    state = BoardState.new
    state.place_wagon(10, 10, 0)
    dests = tile.valid_destinations(
      from_row: 10, from_col: 10,
      board_contents: state, board: all_grass_board, player_order: 0
    )
    assert_includes dests, [ 10, 11 ]
    assert_includes dests, [ 10, 12 ]
    assert_includes dests, [ 10, 13 ]
    assert_not_includes dests, [ 10, 14 ]
    assert_not_includes dests, [ 10, 10 ]
  end

  test "valid_destinations (move) does not include water hexes" do
    terrain = {}
    20.times { |r| 20.times { |c| terrain[[ r, c ]] = "G" } }
    terrain[[ 10, 11 ]] = "W"
    state = BoardState.new
    state.place_wagon(10, 10, 0)
    dests = tile.valid_destinations(
      from_row: 10, from_col: 10,
      board_contents: state, board: BoardStub.new(terrain), player_order: 0
    )
    assert_not_includes dests, [ 10, 11 ]
  end

  test "valid_destinations (move) does not include occupied hexes" do
    state = BoardState.new
    state.place_wagon(10, 10, 0)
    state.place_settlement(10, 11, 1)
    dests = tile.valid_destinations(
      from_row: 10, from_col: 10,
      board_contents: state, board: all_grass_board, player_order: 0
    )
    assert_not_includes dests, [ 10, 11 ]
  end

  test "valid_destinations (move) can traverse mountain hexes" do
    terrain = {}
    20.times { |r| 20.times { |c| terrain[[ r, c ]] = "M" } }
    state = BoardState.new
    state.place_wagon(10, 10, 0)
    dests = tile.valid_destinations(
      from_row: 10, from_col: 10,
      board_contents: state, board: BoardStub.new(terrain), player_order: 0
    )
    assert_includes dests, [ 10, 11 ]
    assert_includes dests, [ 10, 12 ]
    assert_includes dests, [ 10, 13 ]
  end

  # --- selectable_wagons ---

  test "selectable_wagons returns wagon coords when wagon can move" do
    state = BoardState.new
    state.place_wagon(10, 10, 0)
    result = tile.selectable_wagons(player_order: 0, board_contents: state, board: all_grass_board)
    assert_includes result, [ 10, 10 ]
  end

  test "selectable_wagons returns empty when wagon surrounded by water" do
    state = BoardState.new
    state.place_wagon(5, 5, 0)
    result = tile.selectable_wagons(player_order: 0, board_contents: state, board: all_water_board)
    assert_equal [], result
  end
end
