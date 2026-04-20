require "test_helper"

class Tiles::VillageTileTest < ActiveSupport::TestCase
  # VillageBoard at index 0, rows 0–9 cols 0–9:
  #   row 0: D D D D D D D G G G
  #   row 1: D D D M D F F F G G
  #   row 2: D M D D D F W F G T
  # We need a hex adjacent to >= 3 player settlements.
  # Place 3 settlements around a central empty hex and verify it appears in valid_destinations.
  #
  # (0,3)=D even-row neighbors: (0,2),(0,4) and odd-row up/down neighbors.
  # BoardState::ADJACENCIES even row: [[-1,-1],[-1,0],[0,-1],[0,1],[1,-1],[1,0]]
  # So neighbors of (0,3) on even row: (-1,2),(-1,3),(0,2),(0,4),(1,2),(1,3)
  # In-bounds: (0,2)=D, (0,4)=D, (1,2)=D, (1,3)=M
  # If we place settlements at (0,2), (0,4), (1,2) then (0,3)=D should have 3 neighbors.

  def setup_board
    game = games(:game2player)
    @chris = game_players(:chris)
    game.boards = [ [ 11, 0 ], [ 5, 0 ], [ 0, 0 ], [ 4, 0 ] ]
    state = BoardState.new
    yield state if block_given?
    game.board_contents = state
    game.save
    game.instantiate
    @ctx = { board_contents: game.board_contents, board: game.board }
  end

  test "valid_destinations includes hexes adjacent to 3+ own settlements" do
    setup_board do |s|
      s.place_settlement(0, 2, @chris.order)
      s.place_settlement(0, 4, @chris.order)
      s.place_settlement(1, 2, @chris.order)
    end
    tile = Tiles::VillageTile.new(0)

    result = tile.valid_destinations(**@ctx, player_order: @chris.order)

    assert_includes result, [ 0, 3 ], "hex with 3 adjacent settlements should be included"
  end

  test "valid_destinations excludes hexes adjacent to fewer than 3 own settlements" do
    setup_board do |s|
      s.place_settlement(0, 2, @chris.order)
      s.place_settlement(0, 4, @chris.order)
      # Only 2 neighbors of (0,3)
    end
    tile = Tiles::VillageTile.new(0)

    result = tile.valid_destinations(**@ctx, player_order: @chris.order)

    assert_not_includes result, [ 0, 3 ]
  end

  test "valid_destinations excludes occupied hexes even with 3+ adjacent settlements" do
    setup_board do |s|
      s.place_settlement(0, 2, @chris.order)
      s.place_settlement(0, 4, @chris.order)
      s.place_settlement(1, 2, @chris.order)
      s.place_settlement(0, 3, 1)  # opponent occupies the hex
    end
    tile = Tiles::VillageTile.new(0)

    result = tile.valid_destinations(**@ctx, player_order: @chris.order)

    assert_not_includes result, [ 0, 3 ]
  end

  test "valid_destinations excludes non-buildable terrain" do
    # (1,3)=M is adjacent to (0,2),(0,4),(1,2) settlements but M is not buildable
    setup_board do |s|
      s.place_settlement(0, 2, @chris.order)
      s.place_settlement(0, 4, @chris.order)
      s.place_settlement(1, 2, @chris.order)
    end
    tile = Tiles::VillageTile.new(0)

    result = tile.valid_destinations(**@ctx, player_order: @chris.order)

    result.each { |r, c| assert_includes Tiles::Tile::BUILDABLE_TERRAIN, @ctx[:board].terrain_at(r, c) }
  end

  test "valid_destinations ignores opponent settlements" do
    setup_board do |s|
      s.place_settlement(0, 2, @chris.order)
      s.place_settlement(0, 4, @chris.order)
      s.place_settlement(1, 2, 1)  # opponent's settlement
    end
    tile = Tiles::VillageTile.new(0)

    result = tile.valid_destinations(**@ctx, player_order: @chris.order)

    assert_not_includes result, [ 0, 3 ]
  end

  test "builds_settlement? returns true" do
    assert Tiles::VillageTile.new(0).builds_settlement?
  end

  test "from_hash returns a VillageTile" do
    assert_instance_of Tiles::VillageTile, Tiles::Tile.from_hash("klass" => "VillageTile")
  end
end
