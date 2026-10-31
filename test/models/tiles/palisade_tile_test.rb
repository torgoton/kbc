require "test_helper"

class Tiles::PalisadeTileTest < ActiveSupport::TestCase
  # Section 20 at index 0: rows 0-9, cols 0-9.
  #   row 5 "MCCWWWDDDD"   row 6 "MCCHHHHHDM"   row 7 "MCHHSHHHDD"
  # A row of three at (6,3) (6,4) (6,5). (7,4) is the Silo, (5,3)-(5,5) are water.
  # Open buildable hexes touching (6,3): (5,2) (6,2) (7,2) (7,3). Touching (6,5): (6,6) (7,5).

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

  def tile = Tiles::Location::PalisadeTile.new(0)
  def destinations(ctx, from) = tile.valid_destinations(from_row: from[0], from_col: from[1], **ctx)

  test "the middle of three can move next to either of the others" do
    ctx = board_with([ 6, 3 ], [ 6, 4 ], [ 6, 5 ])

    assert_equal [ [ 5, 2 ], [ 6, 2 ], [ 6, 6 ], [ 7, 2 ], [ 7, 3 ], [ 7, 5 ] ], destinations(ctx, [ 6, 4 ]).sort
  end

  test "an end piece must land next to a different member of its area" do
    ctx = board_with([ 6, 3 ], [ 6, 4 ], [ 6, 5 ])

    assert_equal [ [ 6, 6 ], [ 7, 3 ], [ 7, 5 ] ], destinations(ctx, [ 6, 3 ]).sort
  end

  test "a settlement outside the area does not widen the destinations" do
    ctx = board_with([ 6, 3 ], [ 6, 4 ], [ 6, 7 ])

    result = destinations(ctx, [ 6, 3 ])
    assert_includes result, [ 7, 3 ]
    assert_not_includes result, [ 6, 6 ], "touches only the separate settlement at (6,7)"
  end

  test "excludes occupied hexes" do
    ctx = board_with([ 6, 3 ], [ 6, 4 ], [ 6, 5 ], [ 7, 3, 1 ])

    assert_not_includes destinations(ctx, [ 6, 4 ]), [ 7, 3 ]
  end

  test "a lone settlement cannot use it, a pair can" do
    assert_not tile.activatable?(**board_with([ 6, 3 ]))
    assert tile.activatable?(**board_with([ 6, 3 ], [ 6, 4 ]))
  end

  test "selectable settlements are those with a destination in their area" do
    ctx = board_with([ 6, 3 ], [ 6, 4 ], [ 0, 0 ])

    assert_equal [ [ 6, 3 ], [ 6, 4 ] ], tile.selectable_settlements(**ctx).sort
  end
end
