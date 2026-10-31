require "test_helper"

class Tiles::WaterMillTileTest < ActiveSupport::TestCase
  # Section 20 at index 0: rows 0-9, cols 0-9.
  #   row 4 "TTTCWWFDFD"   row 5 "MCCWWWDDDD"   row 6 "MCCHHHHHDM"   row 7 "MCHHSHHHDD"
  # Settlement at (6,2): of its neighbors only (5,2) Canyon and (6,3) Farmland touch water.
  # (0,3) is Mountain touching water at (0,4): never buildable.

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

  def destinations(ctx) = Tiles::Location::WaterMillTile.new(0).valid_destinations(**ctx)

  test "builds next to water, adjacent to your settlements when possible" do
    assert_equal [ [ 5, 2 ], [ 6, 3 ] ], destinations(board_with([ 6, 2 ])).sort
  end

  test "falls back to any hex next to water when none is adjacent to your settlements" do
    result = destinations(board_with([ 0, 0 ]))

    assert_includes result, [ 5, 2 ]
    assert_includes result, [ 6, 3 ]
    assert_not_includes result, [ 5, 3 ], "water hexes themselves are not buildable"
    assert_not_includes result, [ 0, 3 ], "mountain is not buildable"
    assert_not_includes result, [ 6, 7 ], "farmland not touching water is excluded"
  end

  test "excludes occupied hexes" do
    result = destinations(board_with([ 6, 2 ], [ 6, 3, 1 ]))

    assert_equal [ [ 5, 2 ] ], result
  end

  test "not activatable when every hex next to water is occupied" do
    ctx = board_with([ 6, 2 ])
    all = Tiles::Location::WaterMillTile.new(0).valid_destinations(**ctx)
    state = ctx[:board_contents]
    (0..19).each do |r|
      (0..19).each do |c|
        next unless state.empty?(r, c) && Tiles::Tile::BUILDABLE_TERRAIN.include?(state.terrain_at(r, c)) && state.neighbors(r, c).any? { |nr, nc| state.terrain_at(nr, nc) == "W" }
        state.place_settlement(r, c, 1)
      end
    end

    assert_not_empty all
    assert_not Tiles::Location::WaterMillTile.new(0).activatable?(**ctx)
  end
end
