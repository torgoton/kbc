require "test_helper"

class Tiles::BarracksTileTest < ActiveSupport::TestCase
  BoardStub = Struct.new(:terrain_map) do
    def terrain_at(row, col) = terrain_map.fetch([ row, col ], "")
  end

  def tile = Tiles::BarracksTile.new(2)

  def board_with(**hexes)
    BoardStub.new(hexes.transform_keys { |k| k.is_a?(Array) ? k : k.to_s.split(",").map(&:to_i) })
  end

  def grass_board
    terrain = {}
    20.times { |r| 20.times { |c| terrain[[ r, c ]] = "G" } }
    BoardStub.new(terrain)
  end

  test "places_meeple? is true" do
    assert tile.places_meeple?
  end

  test "on_pickup adds 2 warriors to game_player supply" do
    gp = game_players(:chris)
    tile.on_pickup(game_player: gp)
    assert_equal 2, gp.warriors_remaining
  end

  # valid_destinations: placement candidates
  test "valid_destinations returns empty array when warrior supply is 0 and no warriors on board" do
    state = BoardState.new
    destinations = tile.valid_destinations(board_contents: state, board: grass_board, player_order: 0, warrior_supply: 0)
    assert_equal [], destinations
  end

  test "valid_destinations includes all buildable hexes when warrior in supply and no own settlements" do
    state = BoardState.new
    destinations = tile.valid_destinations(board_contents: state, board: grass_board, player_order: 0, warrior_supply: 1)
    assert_includes destinations, [ 0, 0 ]
    assert_includes destinations, [ 5, 5 ]
  end

  test "valid_destinations excludes occupied hexes when placing" do
    state = BoardState.new
    state.place_settlement(5, 5, 1)
    destinations = tile.valid_destinations(board_contents: state, board: grass_board, player_order: 0, warrior_supply: 1)
    assert_not_includes destinations, [ 5, 5 ]
  end

  test "valid_destinations excludes warrior-blocked hexes when placing" do
    state = BoardState.new
    state.place_warrior(10, 10, 1)
    destinations = tile.valid_destinations(board_contents: state, board: grass_board, player_order: 0, warrior_supply: 1)
    # [10,10] even row; neighbors are [10,9],[10,11],[9,9],[9,10],[11,9],[11,10]
    assert_not_includes destinations, [ 10, 9 ]
    assert_not_includes destinations, [ 9, 10 ]
  end

  test "valid_destinations prefers adjacent hexes when own settlements exist" do
    state = BoardState.new
    state.place_settlement(5, 5, 0)
    # [5,5] is odd row; neighbors are [[5,4],[5,6],[4,5],[4,6],[6,5],[6,6]]
    destinations = tile.valid_destinations(board_contents: state, board: grass_board, player_order: 0, warrior_supply: 1)
    expected_neighbors = state.neighbors(5, 5).select { |r, c| state.empty?(r, c) }
    assert_equal expected_neighbors.sort, destinations.select { |d| expected_neighbors.include?(d) }.sort
    # Should not include non-adjacent hexes when adjacent ones exist
    assert_not_includes destinations, [ 0, 0 ]
  end

  test "valid_destinations falls back to all buildable when no adjacent empty hex exists" do
    state = BoardState.new
    # Surround settlement with warriors/settlements so no adjacent empty hex
    state.place_settlement(0, 0, 0)
    state.place_settlement(0, 1, 1)
    state.place_settlement(1, 0, 1)
    # [0,0] even row neighbors: [0,-1],[0,1],[-1,-1],[-1,0],[1,-1],[1,0]
    # in-bounds: [0,1] and [1,0] — both occupied
    destinations = tile.valid_destinations(board_contents: state, board: grass_board, player_order: 0, warrior_supply: 1)
    assert_includes destinations, [ 5, 5 ]
  end

  # valid_destinations: removal candidates (own warriors on board)
  test "valid_destinations includes own warrior hexes for removal" do
    state = BoardState.new
    state.place_warrior(3, 4, 0)
    destinations = tile.valid_destinations(board_contents: state, board: grass_board, player_order: 0, warrior_supply: 0)
    assert_includes destinations, [ 3, 4 ]
  end

  test "valid_destinations does not include opponent warriors" do
    state = BoardState.new
    state.place_warrior(3, 4, 1)
    destinations = tile.valid_destinations(board_contents: state, board: grass_board, player_order: 0, warrior_supply: 0)
    assert_not_includes destinations, [ 3, 4 ]
  end

  # activatable?
  test "activatable? is true when warrior in supply" do
    state = BoardState.new
    assert tile.activatable?(player_order: 0, board_contents: state, board: grass_board, warrior_supply: 1)
  end

  test "activatable? is true when warrior on board" do
    state = BoardState.new
    state.place_warrior(5, 5, 0)
    assert tile.activatable?(player_order: 0, board_contents: state, board: grass_board, warrior_supply: 0)
  end

  test "activatable? is false when no warriors in supply or on board" do
    state = BoardState.new
    assert_not tile.activatable?(player_order: 0, board_contents: state, board: grass_board, warrior_supply: 0)
  end
end
