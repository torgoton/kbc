require "test_helper"

class Tiles::FortTileTest < ActiveSupport::TestCase
  def tile = Tiles::FortTile.new(0)

  test "fort_tile? is true" do
    assert tile.fort_tile?
  end

  test "builds_settlement? is true" do
    assert tile.builds_settlement?
  end

  test "activatable? returns true regardless of board state" do
    state = BoardState.new
    board = Struct.new(:terrain).new({})
    assert tile.activatable?(player_order: 0, board_contents: state, board: board)
  end

  test "activatable? returns true even with no valid destinations for hand terrain" do
    # Fort doesn't check hand — it draws a new card
    state = BoardState.new
    board = Struct.new(:terrain).new({})
    assert tile.activatable?(player_order: 0, board_contents: state, board: board, hand: "G")
  end
end
