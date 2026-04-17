require "test_helper"

class Tiles::CaravanTileTest < ActiveSupport::TestCase
  # CaravanBoard at index 0, rows 0–9 cols 0–9:
  #   row 5: T T T T C D G G G G
  #   row 6: T T L C C C G G M G
  #   row 7: T C C C C G L D D G
  #   row 8: C M C C C F F F D D
  #
  # Settlement at (6, 4)=C. Slide E: (6,5)=C, (6,6)=G, (6,7)=G -> hits (6,8)=M, stops at (6,7).
  # Slide W from (6,4): (6,3)=C, (6,2)=L (not buildable), stops at (6,3).
  # Slide NE (even row): step [-1,0] -> (5,4)=C, then from (5,4) odd row step [-1,1] -> (4,5)...
  #   row 5: T T T T C D G G G G — (5,4)=C
  #   row 4: T T T W W W D D G G — (4,5)=W not buildable => stops at (5,4).

  def setup_board(row, col)
    game = games(:game2player)
    @chris = game_players(:chris)
    game.boards = [ [ "Caravan", 0 ], [ "Paddock", 0 ], [ "Farm", 0 ], [ "Tavern", 0 ] ]
    state = BoardState.new.tap { |s| s.place_settlement(row, col, @chris.order) }
    yield state if block_given?
    game.board_contents = state
    game.save
    game.instantiate
    @ctx = { board_contents: game.board_contents, board: game.board }
  end

  test "valid_destinations slides east until blocked" do
    setup_board(6, 4)
    tile = Tiles::CaravanTile.new(0)

    result = tile.valid_destinations(from_row: 6, from_col: 4, **@ctx, player_order: @chris.order)

    # Slides E: (6,5)=C, (6,6)=G, (6,7)=G then blocked by (6,8)=M — destination is (6,7)
    assert_includes result, [ 6, 7 ]
    # Intermediate hex (6,5) should NOT appear as a destination
    assert_not_includes result, [ 6, 5 ]
  end

  test "valid_destinations stops at occupied hex" do
    setup_board(6, 4) { |s| s.place_settlement(6, 6, 1) }
    tile = Tiles::CaravanTile.new(0)

    result = tile.valid_destinations(from_row: 6, from_col: 4, **@ctx, player_order: @chris.order)

    # Slides E: (6,5)=C is last valid before (6,6) occupied
    assert_includes result, [ 6, 5 ]
    assert_not_includes result, [ 6, 6 ]
    assert_not_includes result, [ 6, 7 ]
  end

  test "valid_destinations excludes direction where first hex is blocked" do
    # Settlement at (6,4)=C. West: (6,3)=C, (6,2)=L (location tile, not buildable terrain).
    setup_board(6, 4)
    tile = Tiles::CaravanTile.new(0)

    result = tile.valid_destinations(from_row: 6, from_col: 4, **@ctx, player_order: @chris.order)

    # (6,2)=L not in BUILDABLE_TERRAIN — west slides stop at (6,3)
    assert_includes result, [ 6, 3 ]
    assert_not_includes result, [ 6, 2 ]
  end

  test "valid_destinations returns empty if from_row or from_col is nil" do
    setup_board(6, 4)
    tile = Tiles::CaravanTile.new(0)

    assert_empty tile.valid_destinations(from_row: nil, from_col: nil, **@ctx, player_order: @chris.order)
  end

  test "selectable_settlements returns settlements that can slide" do
    setup_board(6, 4)
    tile = Tiles::CaravanTile.new(0)

    result = tile.selectable_settlements(player_order: @chris.order, **@ctx)

    assert_includes result, [ 6, 4 ]
  end

  test "selectable_settlements only returns settlements with valid destinations" do
    # CaravanBoard row 6: T T L C C C G G M G
    # Settlement at (6,2)=L. L is a location hex and not in BUILDABLE_TERRAIN.
    # Neighbors: W direction -> (6,1)=T, (6,0)=T (buildable). E -> (6,3)=C (buildable).
    # So (6,2) itself CAN slide somewhere. Add a second settlement with no valid slides.
    # (6,8)=M — slide W: (6,7)=G, E: (6,9)=G, so it can slide.
    # Use (0,0)=W on CaravanBoard — neighbors are also W. No slides possible.
    setup_board(0, 0) { |s| s.place_settlement(6, 4, @chris.order) }
    tile = Tiles::CaravanTile.new(0)

    result = tile.selectable_settlements(player_order: @chris.order, **@ctx)

    assert_not_includes result, [ 0, 0 ], "settlement at W hex with no buildable slides excluded"
    assert_includes result, [ 6, 4 ], "settlement with valid slides included"
  end

  test "moves_settlement? returns true" do
    assert Tiles::CaravanTile.new(0).moves_settlement?
  end

  test "builds_settlement? returns false" do
    assert_not Tiles::CaravanTile.new(0).builds_settlement?
  end

  test "from_hash returns a CaravanTile" do
    assert_instance_of Tiles::CaravanTile, Tiles::Tile.from_hash("klass" => "CaravanTile")
  end
end
