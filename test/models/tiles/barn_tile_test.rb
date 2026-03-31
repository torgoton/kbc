require "test_helper"

class Tiles::BarnTileTest < ActiveSupport::TestCase
  # Barn board at index 0, rows 0-9 cols 0-9:
  #   row 0: F D D M M D D C C C
  #   row 1: F F D D D M M C C C
  # Settlement at (0,0)=F, hand "F":
  #   even-row neighbor (1,0)=F → adjacent Flower terrain available
  def setup_board(row, col)
    game = games(:game2player)
    @chris = game_players(:chris)
    game.boards = [ [ "Barn", 0 ], [ "Paddock", 0 ], [ "Farm", 0 ], [ "Tavern", 0 ] ]
    state = BoardState.new.tap { |s| s.place_settlement(row, col, @chris.order) }
    yield state if block_given?
    game.board_contents = state
    game.save
    game.instantiate
    @ctx = { board_contents: game.board_contents, board: game.board }
  end

  test "selectable_settlements returns settlements when valid destinations exist" do
    setup_board(0, 0)
    tile = Tiles::BarnTile.new(0)

    result = tile.selectable_settlements(**@ctx, player_order: @chris.order, hand: "F")

    assert_includes result, [ 0, 0 ]
  end

  test "builds_settlement? returns false" do
    assert_not Tiles::BarnTile.new(0).builds_settlement?
  end

  test "from_hash returns a BarnTile" do
    assert_instance_of Tiles::BarnTile, Tiles::Tile.from_hash("klass" => "BarnTile")
  end
end
