require "test_helper"

class Tiles::FarmlandTileTest < ActiveSupport::TestCase
  # Section 20 (Bazaar/Water Mill) sits at index 0: rows 0-9, cols 0-9.
  # Row 6 is "MCCHHHHHDM": farmland at (6,3)-(6,7). (6,2) is Canyon, adjacent to farmland at (6,3).
  # (0,0) is Grass with no farmland nearby.

  def board_with(*settlements)
    game = games(:game2player)
    chris = game_players(:chris)
    game.boards = [ [ 20, 0 ], [ 1, 0 ], [ 0, 0 ], [ 4, 0 ] ]
    state = BoardState.new
    settlements.each { |r, c, order| state.place_settlement(r, c, order || chris.order) }
    game.board_contents = state
    game.save
    game.instantiate
    { board_contents: with_terrain(game.board_contents, game.board), order: chris.order }
  end

  test "valid_destinations is only farmland adjacent to the player's settlements" do
    ctx = board_with([ 6, 2 ])
    result = Tiles::Permanent::FarmlandTile.new(0).valid_destinations(**ctx.slice(:board_contents).merge(player_order: ctx[:order]))

    assert_includes result, [ 6, 3 ]
    assert result.all? { |r, c| ctx[:board_contents].terrain_at(r, c) == "H" }
    assert_not_includes result, [ 6, 6 ], "farmland not adjacent to a settlement is excluded"
  end

  test "valid_destinations excludes occupied farmland" do
    ctx = board_with([ 6, 2 ], [ 6, 3, 1 ])
    result = Tiles::Permanent::FarmlandTile.new(0).valid_destinations(**ctx.slice(:board_contents).merge(player_order: ctx[:order]))

    assert_not_includes result, [ 6, 3 ]
  end

  test "no fallback to distant farmland when none is adjacent" do
    ctx = board_with([ 0, 0 ])
    tile = Tiles::Permanent::FarmlandTile.new(0)

    assert_empty tile.valid_destinations(**ctx.slice(:board_contents).merge(player_order: ctx[:order]))
    assert_not tile.activatable?(**ctx.slice(:board_contents).merge(player_order: ctx[:order]))
  end

  test "activatable when a settlement is adjacent to open farmland" do
    ctx = board_with([ 6, 2 ])

    assert Tiles::Permanent::FarmlandTile.new(0).activatable?(**ctx.slice(:board_contents).merge(player_order: ctx[:order]))
  end

  test "not activatable when all adjacent farmland is occupied" do
    ctx = board_with([ 6, 2 ], [ 6, 3, 1 ], [ 5, 3, 1 ], [ 7, 2, 1 ], [ 7, 3, 1 ])
    tile = Tiles::Permanent::FarmlandTile.new(0)

    assert_not tile.activatable?(**ctx.slice(:board_contents).merge(player_order: ctx[:order]))
  end

  test "farmland is a buildable terrain for other tiles, e.g. Paddock moving two hexes onto it" do
    ctx = board_with([ 6, 2 ])
    result = Tiles::Location::PaddockTile.new(0).valid_destinations(from_row: 6, from_col: 2, board_contents: ctx[:board_contents], player_order: ctx[:order])

    assert_includes result, [ 6, 4 ]
  end
end
