require "test_helper"

class Tiles::GardenTileTest < ActiveSupport::TestCase
  # GardenBoard at index 0, rows 0–9 cols 0–9:
  #   row 3: C G G C C M F M D D
  #   row 4: C G G G D M M F F F
  # Settlement at (3,1)=G. Adjacent flower F hexes:
  #   row 3: (3,6)=F — not adjacent to (3,1)
  # Even-row neighbors of (3,1): (2,0),(2,1),(3,0),(3,2),(4,0),(4,1) — none are F
  # Try settlement at (4,6)=G — odd-row neighbors include (3,6)=F, (4,7)=F

  def setup_board(row, col)
    game = games(:game2player)
    @chris = game_players(:chris)
    game.boards = [ [ "Garden", 0 ], [ "Paddock", 0 ], [ "Farm", 0 ], [ "Tavern", 0 ] ]
    state = BoardState.new.tap { |s| s.place_settlement(row, col, @chris.order) }
    yield state if block_given?
    game.board_contents = state
    game.save
    game.instantiate
    @ctx = { board_contents: game.board_contents, board: game.board }
  end

  test "builds_settlement? returns true" do
    assert Tiles::GardenTile.new(0).builds_settlement?
  end

  test "valid_destinations returns adjacent flower hexes when available" do
    # Settlement at (4,6)=G. Odd-row neighbors: (3,6)=F, (4,7)=F are adjacent F hexes.
    setup_board(4, 6)
    tile = Tiles::GardenTile.new(0)

    result = tile.valid_destinations(**@ctx, player_order: @chris.order)

    assert result.any?
    result.each { |r, c| assert_equal "F", @ctx[:board].terrain_at(r, c) }
  end

  test "valid_destinations includes only empty flower hexes" do
    setup_board(4, 6) { |s| s.place_settlement(3, 6, 1) }
    tile = Tiles::GardenTile.new(0)

    result = tile.valid_destinations(**@ctx, player_order: @chris.order)

    assert_not_includes result, [ 3, 6 ]
    result.each { |r, c| assert_equal "F", @ctx[:board].terrain_at(r, c) }
  end

  test "valid_destinations falls back to all flower hexes when none adjacent" do
    # Settlement at (0,0)=C — no adjacent F hexes
    setup_board(0, 0)
    tile = Tiles::GardenTile.new(0)

    result = tile.valid_destinations(**@ctx, player_order: @chris.order)

    assert result.any?
    result.each { |r, c| assert_equal "F", @ctx[:board].terrain_at(r, c) }
  end

  test "from_hash returns a GardenTile" do
    assert_instance_of Tiles::GardenTile, Tiles::Tile.from_hash("klass" => "GardenTile")
  end
end
