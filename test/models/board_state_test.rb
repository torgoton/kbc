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
    assert_equal [ [ 10, 9 ], [ 10, 11 ], [ 9, 9 ], [ 9, 10 ], [ 11, 9 ], [ 11, 10 ] ].sort, state.neighbors(10, 10).sort
  end

  test "neighbors returns in-bounds adjacent cells for odd row" do
    state = BoardState.new
    # from game.rb comment: [9,10] adjacent to [[9,9],[9,11],[8,10],[8,11],[10,10],[10,11]]
    assert_equal [ [ 9, 9 ], [ 9, 11 ], [ 8, 10 ], [ 8, 11 ], [ 10, 10 ], [ 10, 11 ] ].sort, state.neighbors(9, 10).sort
  end

  test "neighbors clips out-of-bounds neighbors at corner" do
    state = BoardState.new
    # [0,0] is even row; offsets produce [0,-1],[0,1],[-1,-1],[-1,0],[1,-1],[1,0]
    # only [0,1] and [1,0] are in bounds
    assert_equal [ [ 0, 1 ], [ 1, 0 ] ].sort, state.neighbors(0, 0).sort
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
    assert_equal [ [ 9, 9 ] ], occupied
  end

  test "locations_with_remaining_tiles returns coordinates of tiles with qty > 0" do
    state = BoardState.new
    state.place_tile(5, 3, "OasisTile", 2)
    state.place_tile(6, 4, "PaddockTile", 0)
    state.place_settlement(2, 7, 0)
    assert_equal [ [ 5, 3 ] ], state.locations_with_remaining_tiles
  end

  test "settlements_for returns coordinates for that player only" do
    state = BoardState.new
    state.place_settlement(2, 7, 0)
    state.place_settlement(3, 4, 0)
    state.place_settlement(5, 1, 1)
    assert_equal [ [ 2, 7 ], [ 3, 4 ] ].sort, state.settlements_for(0).sort
    assert_equal [ [ 5, 1 ] ], state.settlements_for(1)
    assert_equal [], state.settlements_for(2)
  end

  # Warrior tests
  test "place_warrior stores warrior at cell" do
    state = BoardState.new
    state.place_warrior(3, 5, 0)
    assert_not state.empty?(3, 5)
    assert_equal 0, state.player_at(3, 5)
    assert_equal "warrior", state.meeple_at(3, 5)
  end

  test "meeple_at returns nil for regular settlement" do
    state = BoardState.new
    state.place_settlement(3, 5, 0)
    assert_nil state.meeple_at(3, 5)
  end

  test "meeple_at returns nil for empty cell" do
    assert_nil BoardState.new.meeple_at(0, 0)
  end

  test "warriors_for returns coordinates of warriors for a player" do
    state = BoardState.new
    state.place_warrior(2, 7, 0)
    state.place_settlement(3, 4, 0)
    state.place_warrior(5, 1, 1)
    assert_equal [ [ 2, 7 ] ], state.warriors_for(0)
    assert_equal [ [ 5, 1 ] ], state.warriors_for(1)
  end

  test "settlements_for includes warriors" do
    state = BoardState.new
    state.place_settlement(2, 7, 0)
    state.place_warrior(3, 4, 0)
    assert_equal [ [ 2, 7 ], [ 3, 4 ] ].sort, state.settlements_for(0).sort
  end

  test "warrior_blocked? is false when no warriors on board" do
    state = BoardState.new
    assert_not state.warrior_blocked?(5, 5)
  end

  test "warrior_blocked? is true for hexes adjacent to a warrior" do
    state = BoardState.new
    state.place_warrior(10, 10, 0)
    # [10,10] is even row; neighbors are [10,9],[10,11],[9,9],[9,10],[11,9],[11,10]
    assert state.warrior_blocked?(10, 9)
    assert state.warrior_blocked?(9, 10)
    assert_not state.warrior_blocked?(10, 10) # warrior's own hex is occupied, not "blocked"
    assert_not state.warrior_blocked?(0, 0)
  end

  test "available_for_building? is false when occupied" do
    state = BoardState.new
    state.place_settlement(3, 5, 0)
    assert_not state.available_for_building?(3, 5)
  end

  test "available_for_building? is false when warrior-adjacent" do
    state = BoardState.new
    state.place_warrior(10, 10, 0)
    assert_not state.available_for_building?(10, 9)
  end

  test "available_for_building? is true for empty non-blocked hex" do
    state = BoardState.new
    state.place_warrior(10, 10, 0)
    assert state.available_for_building?(5, 5)
  end

  test "dump/load round-trip preserves warrior meeple type" do
    state = BoardState.new
    state.place_warrior(3, 5, 1)
    reloaded = BoardState.load(BoardState.dump(state))
    assert_equal 1, reloaded.player_at(3, 5)
    assert_equal "warrior", reloaded.meeple_at(3, 5)
  end

  # Ship tests
  test "place_ship stores ship meeple at cell" do
    state = BoardState.new
    state.place_ship(3, 5, 0)
    assert_equal "ship", state.meeple_at(3, 5)
  end

  test "ships_for returns coordinates of ships for a player" do
    state = BoardState.new
    state.place_ship(2, 7, 0)
    state.place_ship(5, 1, 1)
    assert_equal [ [ 2, 7 ] ], state.ships_for(0)
    assert_equal [ [ 5, 1 ] ], state.ships_for(1)
  end

  test "ship_at? is true for ship cell" do
    state = BoardState.new
    state.place_ship(4, 4, 0)
    assert state.ship_at?(4, 4)
  end

  test "ship_at? is false for warrior cell" do
    state = BoardState.new
    state.place_warrior(4, 4, 0)
    assert_not state.ship_at?(4, 4)
  end

  test "ship_at? is false for empty cell" do
    assert_not BoardState.new.ship_at?(0, 0)
  end

  test "settlements_for includes ships" do
    state = BoardState.new
    state.place_ship(3, 4, 0)
    assert_includes state.settlements_for(0), [ 3, 4 ]
  end
end
