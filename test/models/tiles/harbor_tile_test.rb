require "test_helper"

class Tiles::HarborTileTest < ActiveSupport::TestCase
  # Harbor board at index 0, rows 0-9 cols 0-9:
  #   row 0: G G T T T W G T T F   (col 5 = W)
  #   row 1: G F T T W G T T F F   (col 4 = W)
  # Settlement A at (2,0): being moved; no water adjacent to it.
  # Settlement B at (0,4)=T: even-row neighbors (0,5)=W and (1,4)=W are water.
  # When moving A, valid destinations = water hexes adjacent to B = [(0,5), (1,4)].
  def setup_board
    game = games(:game2player)
    @chris = game_players(:chris)
    game.boards = [ [ "Harbor", 0 ], [ "Paddock", 0 ], [ "Farm", 0 ], [ "Tavern", 0 ] ]
    state = BoardState.new.tap do |s|
      s.place_settlement(2, 0, @chris.order)
      s.place_settlement(0, 4, @chris.order)
    end
    yield state if block_given?
    game.board_contents = state
    game.save
    game.instantiate
    @ctx = { board_contents: game.board_contents, board: game.board }
  end

  test "moves_settlement? returns true" do
    assert Tiles::HarborTile.new(0).moves_settlement?
  end

  test "valid_destinations returns water hexes adjacent to other settlements" do
    setup_board
    tile = Tiles::HarborTile.new(0)

    result = tile.valid_destinations(from_row: 2, from_col: 0, **@ctx, player_order: @chris.order)

    assert_includes result, [ 0, 5 ]
    assert_includes result, [ 1, 4 ]
    # Water hexes not adjacent to any other settlement should be excluded
    assert_not_includes result, [ 9, 0 ]
  end

  test "valid_destinations falls back to any water hex when no other settlements are adjacent to water" do
    # Only one settlement — no other settlements to check adjacency against
    game = games(:game2player)
    chris = game_players(:chris)
    game.boards = [ [ "Harbor", 0 ], [ "Paddock", 0 ], [ "Farm", 0 ], [ "Tavern", 0 ] ]
    game.board_contents = BoardState.new.tap { |s| s.place_settlement(2, 0, chris.order) }
    game.save
    game.instantiate
    ctx = { board_contents: game.board_contents, board: game.board }
    tile = Tiles::HarborTile.new(0)

    result = tile.valid_destinations(from_row: 2, from_col: 0, **ctx, player_order: chris.order)

    assert result.any?
    result.each { |r, c| assert_equal "W", ctx[:board].terrain_at(r, c) }
  end

  test "selectable_settlements returns all settlements when empty water exists" do
    setup_board
    tile = Tiles::HarborTile.new(0)

    result = tile.selectable_settlements(**@ctx, player_order: @chris.order)

    assert_includes result, [ 2, 0 ]
    assert_includes result, [ 0, 4 ]
  end

  test "from_hash returns a HarborTile" do
    assert_instance_of Tiles::HarborTile, Tiles::Tile.from_hash("klass" => "HarborTile")
  end
end
