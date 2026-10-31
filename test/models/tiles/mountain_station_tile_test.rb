require "test_helper"

class Tiles::MountainStationTileTest < ActiveSupport::TestCase
  # Section 20 at index 0: rows 0-9, cols 0-9. Mountains run down column 0 at rows 5-7 and sit at (6,9).
  #   row 5 "MCCWWWDDDD"   row 6 "MCCHHHHHDM"   row 7 "MCHHSHHHDD"
  # Settlement at (6,2): of its neighbors only (5,1), (6,1) and (7,1) Canyon touch a mountain.

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

  def destinations(ctx) = Tiles::Location::MountainStationTile.new(0).valid_destinations(**ctx)

  test "builds next to a mountain, adjacent to your settlements when possible" do
    assert_equal [ [ 5, 1 ], [ 6, 1 ], [ 7, 1 ] ], destinations(board_with([ 6, 2 ])).sort
  end

  test "falls back to any hex next to a mountain when none is adjacent to your settlements" do
    result = destinations(board_with([ 9, 9 ]))

    assert_includes result, [ 6, 1 ]
    assert_includes result, [ 7, 9 ]
    assert_not_includes result, [ 6, 0 ], "mountain hexes themselves are not buildable"
    assert_not_includes result, [ 4, 3 ], "hex touching only water is excluded"
  end

  test "excludes occupied hexes" do
    assert_equal [ [ 5, 1 ], [ 7, 1 ] ], destinations(board_with([ 6, 2 ], [ 6, 1, 1 ])).sort
  end

  test "not activatable when no hex next to a mountain is open" do
    ctx = board_with([ 6, 2 ])
    state = ctx[:board_contents]
    (0..19).each do |r|
      (0..19).each do |c|
        next unless state.empty?(r, c) && Tiles::Tile::BUILDABLE_TERRAIN.include?(state.terrain_at(r, c)) && state.neighbors(r, c).any? { |nr, nc| state.terrain_at(nr, nc) == "M" }
        state.place_settlement(r, c, 1)
      end
    end

    assert_not Tiles::Location::MountainStationTile.new(0).activatable?(**ctx)
  end
end
