require "test_helper"

class Tiles::PaddockTileTest < ActiveSupport::TestCase
  # Paddock board at index 1 of the default setup occupies cols 10–19, rows 0–9.
  # A settlement at overall (0,14) = 'D' has buildable straight-line 2-hop destinations:
  #   (0,12)=C (W), (0,16)=D (E)
  # SW lands on (2,13)=M and SE lands on (2,15)=W — excluded by terrain.
  # NW/NE are out of bounds. (1,12) is reachable in 2 hops but NOT a straight line.
  def setup_board
    game = games(:game2player)
    chris = game_players(:chris)
    game.boards = [ [ "Tavern", 0 ], [ "Paddock", 0 ], [ "Oasis", 0 ], [ "Farm", 0 ] ]
    state = BoardState.new.tap { |s| s.place_settlement(0, 14, chris.order) }
    yield state if block_given?
    game.board_contents = state
    game.save
    game.instantiate
    { board_contents: game.board_contents, board: game.board, chris: chris }
  end

  test "valid_destinations returns buildable empty 2-hop cells" do
    ctx = setup_board
    tile = Tiles::PaddockTile.new(0)

    result = tile.valid_destinations(0, 14, board_contents: ctx[:board_contents], board: ctx[:board])

    assert_includes result, [ 0, 12 ], "C terrain straight W 2 hops away"
    assert_includes result, [ 0, 16 ], "D terrain straight E 2 hops away"
    assert_not_includes result, [ 0, 14 ], "origin excluded"
    assert_not_includes result, [ 0, 13 ], "direct neighbor excluded"
    assert_not_includes result, [ 2, 13 ], "M terrain excluded"
    assert_not_includes result, [ 2, 15 ], "W terrain excluded"
    assert_not_includes result, [ 1, 12 ], "not a straight-line destination"
  end

  test "valid_destinations excludes occupied cells" do
    ctx = setup_board { |s| s.place_settlement(0, 12, 1) }
    tile = Tiles::PaddockTile.new(0)

    result = tile.valid_destinations(0, 14, board_contents: ctx[:board_contents], board: ctx[:board])

    assert_not_includes result, [ 0, 12 ], "occupied cell excluded"
    assert_includes result, [ 0, 16 ]
  end

  test "selectable_settlements returns settlements with valid destinations" do
    ctx = setup_board
    tile = Tiles::PaddockTile.new(0)

    result = tile.selectable_settlements(ctx[:chris].order,
      board_contents: ctx[:board_contents], board: ctx[:board])

    assert_includes result, [ 0, 14 ]
  end

  test "selectable_settlements excludes settlements with no valid destinations" do
    ctx = setup_board do |s|
      s.place_settlement(0, 12, 1)
      s.place_settlement(0, 16, 1)
    end
    tile = Tiles::PaddockTile.new(0)

    result = tile.selectable_settlements(ctx[:chris].order,
      board_contents: ctx[:board_contents], board: ctx[:board])

    assert_empty result
  end

  test "base Tile returns empty array for valid_destinations" do
    tile = Tiles::Tile.new(0)
    assert_equal [], tile.valid_destinations(0, 0, board_contents: BoardState.new, board: nil)
  end

  test "base Tile returns empty array for selectable_settlements" do
    tile = Tiles::Tile.new(0)
    assert_equal [], tile.selectable_settlements(0, board_contents: BoardState.new, board: nil)
  end
end
