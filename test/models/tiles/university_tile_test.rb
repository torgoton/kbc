require "test_helper"

class Tiles::UniversityTileTest < ActiveSupport::TestCase
  # Section 20 at index 0: rows 0-9, cols 0-9. Location hexes at (3,2) and (3,6), Silo (silver) at (7,4).
  # Settlement at (8,3): of its neighbors only (7,3) and (8,4), both Farmland, touch the Silo.

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

  def destinations(ctx) = Tiles::Location::UniversityTile.new(0).valid_destinations(**ctx)

  test "builds next to a location or silver hex, adjacent to your settlements when possible" do
    assert_equal [ [ 7, 3 ], [ 8, 4 ] ], destinations(board_with([ 8, 3 ])).sort
  end

  test "falls back to any hex next to a location or silver hex" do
    result = destinations(board_with([ 0, 0 ]))

    assert_includes result, [ 3, 3 ], "next to a location hex"
    assert_includes result, [ 7, 5 ], "next to a silver hex"
    assert_not_includes result, [ 3, 2 ], "location hexes themselves are not buildable"
    assert_not_includes result, [ 7, 4 ], "silver hexes themselves are not buildable"
    assert_not_includes result, [ 8, 2 ], "hex touching neither is excluded"
  end

  test "excludes occupied hexes" do
    assert_equal [ [ 8, 4 ] ], destinations(board_with([ 8, 3 ], [ 7, 3, 1 ]))
  end

  test "not activatable when no hex next to a location or silver hex is open" do
    ctx = board_with([ 8, 3 ])
    state = ctx[:board_contents]
    (0..19).each do |r|
      (0..19).each do |c|
        next unless state.empty?(r, c) && Tiles::Tile::BUILDABLE_TERRAIN.include?(state.terrain_at(r, c)) && state.neighbors(r, c).any? { |nr, nc| %w[L S].include?(state.terrain_at(nr, nc)) }
        state.place_settlement(r, c, 1)
      end
    end

    assert_not Tiles::Location::UniversityTile.new(0).activatable?(**ctx)
  end
end
