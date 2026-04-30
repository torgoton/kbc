require "test_helper"

class Tiles::CityHallTileTest < ActiveSupport::TestCase
  BoardStub = Struct.new(:terrain_map) do
    def terrain_at(row, col) = terrain_map.fetch([ row, col ], "M")
  end

  # A 20x20 all-grass board
  def all_grass_board
    terrain = {}
    20.times { |r| 20.times { |c| terrain[[ r, c ]] = "G" } }
    BoardStub.new(terrain)
  end

  # For a center at [10, 10] (even row), neighbors are:
  # [10,9],[10,11],[9,9],[9,10],[11,9],[11,10]
  def cluster_for(row, col)
    state = BoardState.new
    state.neighbors(row, col).unshift([ row, col ])
  end

  def tile = Tiles::CityHallTile.new(2)

  test "places_city_hall? returns true" do
    assert tile.places_city_hall?
  end

  test "on_pickup grants 1 city_hall piece to game_player supply" do
    gp = game_players(:chris)
    tile.on_pickup(game_player: gp)
    assert_equal 1, gp.city_halls_remaining
  end

  test "activatable? returns false when city_hall supply is 0" do
    state = BoardState.new
    state.place_settlement(10, 8, 0)
    assert_not tile.activatable?(player_order: 0, board_contents: state, board: all_grass_board, supply: { "city_hall" => 0 })
  end

  test "activatable? returns false when no valid center exists" do
    state = BoardState.new
    # No settlements adjacent to any cluster
    assert_not tile.activatable?(player_order: 0, board_contents: state, board: all_grass_board, supply: { "city_hall" => 1 })
  end

  test "activatable? returns true when supply available and valid center exists" do
    state = BoardState.new
    # settlement at [10,8] is adjacent to cluster centered at [10,10] via outer hex [10,9]
    state.place_settlement(10, 8, 0)
    assert tile.activatable?(player_order: 0, board_contents: state, board: all_grass_board, supply: { "city_hall" => 1 })
  end

  test "valid_destinations returns valid center hexes" do
    state = BoardState.new
    state.place_settlement(10, 8, 0)
    result = tile.valid_destinations(board_contents: state, board: all_grass_board, player_order: 0, supply: { "city_hall" => 1 })
    assert_includes result, [ 10, 10 ]
  end

  test "valid_destinations excludes centers where a cluster hex is occupied" do
    state = BoardState.new
    state.place_settlement(10, 8, 0)
    state.place_settlement(10, 9, 1)  # occupies one cluster hex
    result = tile.valid_destinations(board_contents: state, board: all_grass_board, player_order: 0, supply: { "city_hall" => 1 })
    assert_not_includes result, [ 10, 10 ]
  end

  test "valid_destinations excludes centers where a cluster hex has non-buildable terrain" do
    terrain = {}
    20.times { |r| 20.times { |c| terrain[[ r, c ]] = "G" } }
    terrain[[ 10, 9 ]] = "M"  # one cluster hex is mountain
    state = BoardState.new
    state.place_settlement(10, 8, 0)
    result = tile.valid_destinations(board_contents: state, board: BoardStub.new(terrain), player_order: 0, supply: { "city_hall" => 1 })
    assert_not_includes result, [ 10, 10 ]
  end

  test "valid_destinations excludes centers not adjacent to any player settlement" do
    state = BoardState.new
    # No settlements anywhere — cluster at [10,10] has no adjacent player settlement
    result = tile.valid_destinations(board_contents: state, board: all_grass_board, player_order: 0, supply: { "city_hall" => 1 })
    assert_not_includes result, [ 10, 10 ]
  end

  test "valid_destinations counts opponent city_hall hexes as blocking cluster" do
    state = BoardState.new
    state.place_settlement(10, 8, 0)
    state.place_city_hall_hex(10, 9, 1)  # opponent's city hall hex in the cluster
    result = tile.valid_destinations(board_contents: state, board: all_grass_board, player_order: 0, supply: { "city_hall" => 1 })
    assert_not_includes result, [ 10, 10 ]
  end

  test "valid_destinations: own settlement adjacent to outer hex (not center) satisfies adjacency" do
    state = BoardState.new
    # [10,8] is adjacent to [10,9] which is an outer cluster hex of center [10,10]
    state.place_settlement(10, 8, 0)
    result = tile.valid_destinations(board_contents: state, board: all_grass_board, player_order: 0, supply: { "city_hall" => 1 })
    assert_includes result, [ 10, 10 ]
  end

  test "valid_destinations: opponent settlement does not satisfy adjacency" do
    state = BoardState.new
    state.place_settlement(10, 8, 1)  # opponent player, order 1
    result = tile.valid_destinations(board_contents: state, board: all_grass_board, player_order: 0, supply: { "city_hall" => 1 })
    assert_not_includes result, [ 10, 10 ]
  end

  test "action_message describes city hall placement" do
    msg = tile.action_message(player_handle: "Alice", terrain_names: {})
    assert_match(/City Hall/, msg)
  end
end
