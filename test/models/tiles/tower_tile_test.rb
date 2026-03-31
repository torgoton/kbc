require "test_helper"

class Tiles::TowerTileTest < ActiveSupport::TestCase
  # Tower board at index 0, rows 0-9 cols 0-9:
  #   row 0: T T T T M M G M C C
  #   row 1: T M T T F G M M M C
  # Settlement at (1,1): odd-row neighbors are (1,0),(1,2),(0,1),(0,2),(2,1),(2,2).
  # Border neighbors: (1,0)=T, (0,1)=T, (0,2)=T — all buildable.
  def setup_board
    game = games(:game2player)
    @chris = game_players(:chris)
    game.boards = [ [ "Tower", 0 ], [ "Paddock", 0 ], [ "Farm", 0 ], [ "Tavern", 0 ] ]
    state = BoardState.new.tap { |s| s.place_settlement(1, 1, @chris.order) }
    yield state if block_given?
    game.board_contents = state
    game.save
    game.instantiate
    @ctx = { board_contents: game.board_contents, board: game.board }
  end

  test "builds_settlement? returns true" do
    assert Tiles::TowerTile.new(0).builds_settlement?
  end

  test "valid_destinations returns adjacent buildable border hexes" do
    setup_board
    tile = Tiles::TowerTile.new(0)

    result = tile.valid_destinations(**@ctx, player_order: @chris.order)

    assert_includes result, [ 1, 0 ]
    assert_includes result, [ 0, 1 ]
    assert_includes result, [ 0, 2 ]
    # (0,4) and (0,5) are on the border but not adjacent to the settlement
    assert_not_includes result, [ 0, 4 ]
    assert_not_includes result, [ 0, 5 ]
  end

  test "valid_destinations falls back to any buildable border hex when no adjacent border hex exists" do
    # Settlement at (5,5) — interior, no neighbors on the border
    game = games(:game2player)
    chris = game_players(:chris)
    game.boards = [ [ "Tower", 0 ], [ "Paddock", 0 ], [ "Farm", 0 ], [ "Tavern", 0 ] ]
    game.board_contents = BoardState.new.tap { |s| s.place_settlement(5, 5, chris.order) }
    game.save
    game.instantiate
    ctx = { board_contents: game.board_contents, board: game.board }
    tile = Tiles::TowerTile.new(0)

    result = tile.valid_destinations(**ctx, player_order: chris.order)

    assert result.any?
    result.each { |r, c| assert(r == 0 || r == 19 || c == 0 || c == 19, "#{[ r, c ]} is not a border hex") }
    result.each { |r, c| assert_includes %w[C D F G T], ctx[:board].terrain_at(r, c) }
  end

  test "valid_destinations excludes occupied border hexes" do
    setup_board { |s| s.place_settlement(0, 1, 1) }
    tile = Tiles::TowerTile.new(0)

    result = tile.valid_destinations(**@ctx, player_order: @chris.order)

    assert_not_includes result, [ 0, 1 ]
  end

  test "from_hash returns a TowerTile" do
    assert_instance_of Tiles::TowerTile, Tiles::Tile.from_hash("klass" => "TowerTile")
  end
end
