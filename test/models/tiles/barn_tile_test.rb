require "test_helper"

class Tiles::BarnTileTest < ActiveSupport::TestCase
  # Barn board at index 0, rows 0-9 cols 0-9:
  #   row 0: F D D M M D D C C C
  #   row 1: F F D D D M M C C C
  # Settlement at (0,0)=F, hand "F":
  #   even-row neighbor (1,0)=F → adjacent Flower terrain available
  def setup_board(row, col)
    game = games(:game2player)
    @chris = game_players(:chris)
    game.boards = [ [ 6, 0 ], [ 5, 0 ], [ 0, 0 ], [ 4, 0 ] ]
    state = BoardState.new.tap { |s| s.place_settlement(row, col, @chris.order) }
    yield state if block_given?
    game.board_contents = state
    game.save
    game.instantiate
    @ctx = { board_contents: game.board_contents, board: game.board }
  end

  test "selectable_settlements returns settlements when valid destinations exist" do
    setup_board(0, 0)
    tile = Tiles::BarnTile.new(0)

    result = tile.selectable_settlements(**@ctx, player_order: @chris.order, hand: "F")

    assert_includes result, [ 0, 0 ]
  end

  test "valid_destinations does not count the moved settlement as a neighbor anchor" do
    # BarnBoard row 6: "GGLTTFWFFT" → (6,3)=T
    # Even-row neighbors of (6,3) include (5,2)=C and (5,3)=C (Canyon).
    # With the bug, moving FROM (6,3) with hand "C" would return only those two
    # adjacent Canyon spaces instead of all Canyon spaces (fallback).
    setup_board(6, 3)
    tile = Tiles::BarnTile.new(0)

    result = tile.valid_destinations(from_row: 6, from_col: 3, **@ctx, player_order: @chris.order, hand: "C")

    # With the bug: only 2 results (adjacent to the from-settlement).
    # After fix: all Canyon spaces on the board.
    assert result.size > 2, "expected fallback to all Canyon spaces, got #{result.inspect}"
  end

  test "builds_settlement? returns false" do
    assert_not Tiles::BarnTile.new(0).builds_settlement?
  end

  test "from_hash returns a BarnTile" do
    assert_instance_of Tiles::BarnTile, Tiles::Tile.from_hash("klass" => "BarnTile")
  end
end
