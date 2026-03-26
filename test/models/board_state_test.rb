require "test_helper"

class BoardStateTest < ActiveSupport::TestCase
  test "player_at returns player after place_settlement" do
    state = BoardState.new
    state.place_settlement(2, 7, 0)
    assert_equal 0, state.player_at(2, 7)
  end

  test "empty? is true for unoccupied cell and false after placing settlement" do
    state = BoardState.new
    assert state.empty?(2, 7)
    state.place_settlement(2, 7, 0)
    assert_not state.empty?(2, 7)
  end

  test "remove clears a cell" do
    state = BoardState.new
    state.place_settlement(2, 7, 0)
    state.remove(2, 7)
    assert state.empty?(2, 7)
    assert_nil state.player_at(2, 7)
  end

  test "tile_qty and tile_klass read tile cells" do
    state = BoardState.new
    state.place_tile(5, 3, "OasisTile", 2)
    assert_equal 2, state.tile_qty(5, 3)
    assert_equal "OasisTile", state.tile_klass(5, 3)
    assert_equal 0, state.tile_qty(0, 0)
    assert_nil state.tile_klass(0, 0)
  end

  test "decrement_tile and increment_tile mutate qty" do
    state = BoardState.new
    state.place_tile(5, 3, "OasisTile", 2)
    state.decrement_tile(5, 3)
    assert_equal 1, state.tile_qty(5, 3)
    state.decrement_tile(5, 3)
    assert_equal 0, state.tile_qty(5, 3)
    state.increment_tile(5, 3)
    assert_equal 1, state.tile_qty(5, 3)
  end

  test "decrement_tile raises when qty is already 0" do
    state = BoardState.new
    state.place_tile(5, 3, "OasisTile", 0)
    assert_raises(ArgumentError) { state.decrement_tile(5, 3) }
  end

  test "move_settlement is atomic: source cleared, destination placed" do
    state = BoardState.new
    state.place_settlement(2, 7, 1)
    state.move_settlement(2, 7, 4, 3)
    assert state.empty?(2, 7)
    assert_equal 1, state.player_at(4, 3)
  end

  test "neighbors returns in-bounds adjacent cells for even row" do
    state = BoardState.new
    # from game.rb comment: [10,10] adjacent to [[10,9],[10,11],[9,9],[9,10],[11,9],[11,10]]
    assert_equal [ [10,9],[10,11],[9,9],[9,10],[11,9],[11,10] ].sort, state.neighbors(10, 10).sort
  end

  test "neighbors returns in-bounds adjacent cells for odd row" do
    state = BoardState.new
    # from game.rb comment: [9,10] adjacent to [[9,9],[9,11],[8,10],[8,11],[10,10],[10,11]]
    assert_equal [ [9,9],[9,11],[8,10],[8,11],[10,10],[10,11] ].sort, state.neighbors(9, 10).sort
  end

  test "neighbors clips out-of-bounds neighbors at corner" do
    state = BoardState.new
    # [0,0] is even row; offsets produce [0,-1],[0,1],[-1,-1],[-1,0],[1,-1],[1,0]
    # only [0,1] and [1,0] are in bounds
    assert_equal [ [0,1],[1,0] ].sort, state.neighbors(0, 0).sort
  end

  test "dump and load round-trip preserves all cells" do
    state = BoardState.new
    state.place_settlement(2, 7, 0)
    state.place_tile(5, 3, "OasisTile", 2)
    state.place_tile(6, 4, "PaddockTile", 0)

    reloaded = BoardState.load(BoardState.dump(state))

    assert_equal 0, reloaded.player_at(2, 7)
    assert_equal "OasisTile", reloaded.tile_klass(5, 3)
    assert_equal 2, reloaded.tile_qty(5, 3)
    assert_equal "PaddockTile", reloaded.tile_klass(6, 4)
    assert_equal 0, reloaded.tile_qty(6, 4)
    assert reloaded.empty?(0, 0)
  end

  test "neighbors_where filters by block" do
    state = BoardState.new
    state.place_settlement(9, 9, 0)
    occupied = state.neighbors_where(9, 10) { |r, c| !state.empty?(r, c) }
    assert_equal [ [9, 9] ], occupied
  end

  test "key and parse_key are inverses" do
    state = BoardState.new
    assert_equal "[2, 7]", state.key(2, 7)
    assert_equal [2, 7], BoardState.parse_key("[2, 7]")
    assert_equal [2, 7], BoardState.parse_key(state.key(2, 7))
  end

  test "locations_with_remaining_tiles returns coordinates of tiles with qty > 0" do
    state = BoardState.new
    state.place_tile(5, 3, "OasisTile", 2)
    state.place_tile(6, 4, "PaddockTile", 0)
    state.place_settlement(2, 7, 0)
    assert_equal [ [5, 3] ], state.locations_with_remaining_tiles
  end

  test "settlements_for returns coordinates for that player only" do
    state = BoardState.new
    state.place_settlement(2, 7, 0)
    state.place_settlement(3, 4, 0)
    state.place_settlement(5, 1, 1)
    assert_equal [ [2, 7], [3, 4] ].sort, state.settlements_for(0).sort
    assert_equal [ [5, 1] ], state.settlements_for(1)
    assert_equal [], state.settlements_for(2)
  end
end
