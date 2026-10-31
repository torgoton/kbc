require "test_helper"

class Tiles::WatchtowerTileTest < ActiveSupport::TestCase
  # Section 20 at index 0: rows 0-9, cols 0-9.
  #   row 5 "MCCWWWDDDD"   row 6 "MCCHHHHHDM"   row 7 "MCHHSHHHDD"
  # Mine at (6,2), opponent at (6,4). Open hexes touching the opponent: (6,3), (6,5), (7,3).
  # (5,3) and (5,4) are water; (7,4) is the Silo.

  def board_with(*settlements)
    game = games(:game2player)
    chris = game_players(:chris)
    game.boards = [ [ 20, 0 ], [ 1, 0 ], [ 0, 0 ], [ 4, 0 ] ]
    state = BoardState.new
    settlements.each { |r, c, order| state.place_settlement(r, c, order || chris.order) }
    game.board_contents = state
    game.save
    game.instantiate
    { board_contents: with_terrain(game.board_contents, game.board), player_order: chris.order }
  end

  def destinations(ctx) = Tiles::Location::WatchtowerTile.new(0).valid_destinations(**ctx)

  test "builds next to an opponent, adjacent to your settlements when possible" do
    assert_equal [ [ 6, 3 ] ], destinations(board_with([ 6, 2 ], [ 6, 4, 1 ]))
  end

  test "falls back to any hex next to an opponent" do
    assert_equal [ [ 6, 3 ], [ 6, 5 ], [ 7, 3 ] ], destinations(board_with([ 0, 0 ], [ 6, 4, 1 ])).sort
  end

  test "considers every opponent and excludes occupied hexes" do
    assert_equal [ [ 5, 2 ], [ 7, 2 ] ], destinations(board_with([ 6, 2 ], [ 6, 4, 1 ], [ 6, 3, 1 ])).sort
  end

  test "your own settlements do not count as opponents" do
    ctx = board_with([ 6, 2 ])

    assert_empty destinations(ctx)
    assert_not Tiles::Location::WatchtowerTile.new(0).activatable?(**ctx)
  end

  test "activatable when an opponent has an open buildable neighbor" do
    assert Tiles::Location::WatchtowerTile.new(0).activatable?(**board_with([ 0, 0 ], [ 6, 4, 1 ]))
  end
end
