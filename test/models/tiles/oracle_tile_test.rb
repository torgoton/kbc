require "test_helper"

class Tiles::OracleTileTest < ActiveSupport::TestCase
  # Oracle board at index 0, rows 0-9 cols 0-9:
  #   row 0: G G G T T W G T T T
  # Settlement at (0,3)=T, hand "G":
  #   even-row neighbor (0,2)=G → adjacent Grass available

  def setup_board(row, col)
    game = games(:game2player)
    @chris = game_players(:chris)
    game.boards = [ [ "Oracle", 0 ], [ "Paddock", 0 ], [ "Farm", 0 ], [ "Tavern", 0 ] ]
    state = BoardState.new.tap { |s| s.place_settlement(row, col, @chris.order) }
    yield state if block_given?
    game.board_contents = state
    game.save
    game.instantiate
    @ctx = { board_contents: game.board_contents, board: game.board }
  end

  # row 8: W W W D D D D M C C — neighbors of (8,0) are all W/C, no Grass
  test "valid_destinations falls back to any empty hand-terrain hex when no adjacent match" do
    setup_board(8, 0)
    tile = Tiles::OracleTile.new(0)

    result = tile.valid_destinations(**@ctx, player_order: @chris.order, hand: "G")

    assert result.any?
    result.each { |r, c| assert_equal "G", @ctx[:board].terrain_at(r, c) }
  end

  test "valid_destinations uses hand to determine terrain" do
    setup_board(8, 0)
    tile = Tiles::OracleTile.new(0)

    result = tile.valid_destinations(**@ctx, player_order: @chris.order, hand: "D")

    assert result.any?
    result.each { |r, c| assert_equal "D", @ctx[:board].terrain_at(r, c) }
  end

  test "valid_destinations excludes occupied hexes" do
    setup_board(0, 3) { |s| s.place_settlement(0, 2, 1) }
    tile = Tiles::OracleTile.new(0)

    result = tile.valid_destinations(**@ctx, player_order: @chris.order, hand: "G")

    assert_not_includes result, [ 0, 2 ]
  end

  test "valid_destinations returns adjacent hand-terrain hexes" do
    setup_board(0, 3)
    tile = Tiles::OracleTile.new(0)

    result = tile.valid_destinations(**@ctx, player_order: @chris.order, hand: "G")

    assert_includes result, [ 0, 2 ]
    result.each { |r, c| assert_equal "G", @ctx[:board].terrain_at(r, c) }
  end
end
