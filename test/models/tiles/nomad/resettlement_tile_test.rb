require "test_helper"

class Tiles::Nomad::ResettlementTileTest < ActiveSupport::TestCase
  # QuarryBoard at index 0: rows 0-9, cols 0-9
  # Row 0: GGGWWWMCCC
  # Row 1: GGWTDWWWCC
  # Row 2: GMWTLDDDWM
  # (G=Grass, W=Water, M=Mountain, C=Canyon, D=Desert, T=Timber, F=Flower, L=tile)
  # BUILDABLE_TERRAIN = %w[C D F G T]

  def setup
    @game = games(:game2player)
    @chris = game_players(:chris)
    @tile = Tiles::Nomad::ResettlementTile.new(0)
  end

  def setup_board(boards: [ [ 10, 0 ], [ 5, 0 ], [ 0, 0 ], [ 4, 0 ] ])
    @game.boards = boards
    state = BoardState.new
    yield state if block_given?
    @game.board_contents = state
    @game.save
    @game.instantiate
    { board_contents: @game.board_contents, board: @game.board }
  end

  # --- moves_settlement? ---

  test "moves_settlement? returns true" do
    assert @tile.moves_settlement?
  end

  # --- valid_destinations ---

  test "returns [] when from_row/from_col is nil" do
    ctx = setup_board { |s| s.place_settlement(0, 0, @chris.order) }
    result = @tile.valid_destinations(board_contents: ctx[:board_contents], board: ctx[:board], player_order: @chris.order)
    assert_equal [], result
  end

  test "returns [] when budget is 0" do
    ctx = setup_board { |s| s.place_settlement(0, 0, @chris.order) }
    result = @tile.valid_destinations(
      from_row: 0, from_col: 0,
      board_contents: ctx[:board_contents], board: ctx[:board], player_order: @chris.order,
      budget: 0
    )
    assert_equal [], result
  end

  test "returns adjacent buildable empty hexes within budget=1" do
    # Settlement at (0,0) [G]. Neighbors of even row (0,0):
    # ADJACENCIES[0] = [[0,-1],[0,1],[-1,-1],[-1,0],[1,-1],[1,0]]
    # (0,-1) invalid, (0,1)=G buildable, (-1,x) invalid, (1,-1) invalid, (1,0)=G buildable
    ctx = setup_board { |s| s.place_settlement(0, 0, @chris.order) }
    result = @tile.valid_destinations(
      from_row: 0, from_col: 0,
      board_contents: ctx[:board_contents], board: ctx[:board], player_order: @chris.order,
      budget: 1
    )
    assert_includes result, [ 0, 1 ]
    assert_includes result, [ 1, 0 ]
    # Water (W) at (0,3) is not buildable; Mountain (M) is not buildable
    result.each do |r, c|
      assert_includes Tiles::Tile::BUILDABLE_TERRAIN, ctx[:board].terrain_at(r, c),
        "all destinations must be buildable terrain, but [#{r},#{c}] is #{ctx[:board].terrain_at(r, c)}"
    end
  end

  test "BFS reaches hexes 2 steps away with budget=2" do
    # (0,0) -> (0,1) -> (0,2) is 2 steps, all G terrain
    ctx = setup_board { |s| s.place_settlement(0, 0, @chris.order) }
    result = @tile.valid_destinations(
      from_row: 0, from_col: 0,
      board_contents: ctx[:board_contents], board: ctx[:board], player_order: @chris.order,
      budget: 2
    )
    assert_includes result, [ 0, 2 ], "should reach 2 steps away"
  end

  test "BFS does not exceed budget" do
    # With budget=1, should NOT include (0,2) which is 2 steps from (0,0)
    ctx = setup_board { |s| s.place_settlement(0, 0, @chris.order) }
    result = @tile.valid_destinations(
      from_row: 0, from_col: 0,
      board_contents: ctx[:board_contents], board: ctx[:board], player_order: @chris.order,
      budget: 1
    )
    refute_includes result, [ 0, 2 ], "budget=1 should not reach 2 steps away"
  end

  test "vacated hexes are passable" do
    # Settlement at (0,2) [G]. Place another settlement at (0,1) to block direct path.
    # If (0,1) is vacated (treated as empty), BFS can pass through it.
    ctx = setup_board do |s|
      s.place_settlement(0, 2, @chris.order)
      s.place_settlement(0, 1, @chris.order)  # blocks (0,1) normally
    end

    # Without vacated, (0,1) is occupied — should not appear as destination
    result_no_vacated = @tile.valid_destinations(
      from_row: 0, from_col: 2,
      board_contents: ctx[:board_contents], board: ctx[:board], player_order: @chris.order,
      budget: 2, vacated: []
    )
    refute_includes result_no_vacated, [ 0, 1 ], "occupied hex should not be a destination without vacated"

    # With (0,1) in vacated, BFS can pass through it
    result_with_vacated = @tile.valid_destinations(
      from_row: 0, from_col: 2,
      board_contents: ctx[:board_contents], board: ctx[:board], player_order: @chris.order,
      budget: 2, vacated: [ "[0, 1]" ]
    )
    assert_includes result_with_vacated, [ 0, 1 ], "vacated hex should be reachable"
    assert_includes result_with_vacated, [ 0, 0 ], "hex beyond vacated should be reachable with remaining budget"
  end

  test "non-buildable terrain is excluded from destinations" do
    # (0,0) is G, (0,3) is W (Water, not buildable)
    # Settlement at (0,2) [G]; with budget=1, (0,3)[W] should not appear
    ctx = setup_board { |s| s.place_settlement(0, 2, @chris.order) }
    result = @tile.valid_destinations(
      from_row: 0, from_col: 2,
      board_contents: ctx[:board_contents], board: ctx[:board], player_order: @chris.order,
      budget: 1
    )
    refute_includes result, [ 0, 3 ], "Water terrain should not be a valid destination"
  end

  # --- selectable_settlements ---

  test "selectable_settlements returns [] when budget is 0" do
    ctx = setup_board { |s| s.place_settlement(0, 0, @chris.order) }
    result = @tile.selectable_settlements(
      player_order: @chris.order, board_contents: ctx[:board_contents], board: ctx[:board],
      budget: 0
    )
    assert_equal [], result
  end

  test "selectable_settlements returns settlements with reachable destinations" do
    # Settlement at (0,0) [G] has buildable neighbors
    ctx = setup_board { |s| s.place_settlement(0, 0, @chris.order) }
    result = @tile.selectable_settlements(
      player_order: @chris.order, board_contents: ctx[:board_contents], board: ctx[:board],
      budget: 4
    )
    assert_includes result, [ 0, 0 ]
  end

  test "selectable_settlements excludes settlements with no reachable destinations" do
    # Completely surrounded settlement has no valid destinations.
    # Surround (1,1) [G] with settlements on all neighbors so it can't move.
    # Row 1 col 1 is G. Even row 1 is odd (1%2==1), so neighbors use ADJACENCIES[1]:
    # [[0,-1],[0,1],[-1,0],[-1,1],[1,0],[1,1]]
    # neighbors of (1,1): (1,0),(1,2),(0,1),(0,2),(2,1),(2,2)
    ctx = setup_board do |s|
      s.place_settlement(1, 1, @chris.order)  # the trapped settlement
      s.place_settlement(1, 0, @chris.order)
      s.place_settlement(1, 2, @chris.order)
      s.place_settlement(0, 1, @chris.order)
      s.place_settlement(0, 2, @chris.order)
      s.place_settlement(2, 1, @chris.order)
      s.place_settlement(2, 2, @chris.order)
    end
    result = @tile.selectable_settlements(
      player_order: @chris.order, board_contents: ctx[:board_contents], board: ctx[:board],
      budget: 1
    )
    refute_includes result, [ 1, 1 ], "trapped settlement should not be selectable"
  end

  test "selectable_settlements excludes city_hall hexes even when they have valid destinations" do
    all_grass = Object.new.tap { |b| b.define_singleton_method(:terrain_at) { |r, c| "G" } }
    state = BoardState.new
    state.place_settlement(10, 10, @chris.order)
    state.place_city_hall_hex(10, 14, @chris.order)
    result = @tile.selectable_settlements(player_order: @chris.order, board_contents: state, board: all_grass)
    assert_includes result, [ 10, 10 ]
    refute_includes result, [ 10, 14 ]
  end

  # --- activatable? ---

  test "activatable? returns true when there are selectable settlements" do
    ctx = setup_board { |s| s.place_settlement(0, 0, @chris.order) }
    assert @tile.activatable?(
      player_order: @chris.order, board_contents: ctx[:board_contents], board: ctx[:board]
    )
  end

  test "activatable? returns false when no settlements present" do
    ctx = setup_board
    refute @tile.activatable?(
      player_order: @chris.order, board_contents: ctx[:board_contents], board: ctx[:board]
    )
  end
end
