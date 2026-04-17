require "test_helper"

class Tiles::Nomad::OutpostTileTest < ActiveSupport::TestCase
  def setup
    @tile = Tiles::Nomad::OutpostTile.new(0)
  end

  test "outpost_tile? returns true" do
    assert @tile.outpost_tile?
  end

  test "activatable? returns false" do
    refute @tile.activatable?(player_order: 0, board_contents: BoardState.new, board: nil)
  end

  test "nomad_tile? returns true" do
    assert @tile.nomad_tile?
  end

  test "builds_settlement? returns false" do
    refute @tile.builds_settlement?
  end

  test "moves_settlement? returns false" do
    refute @tile.moves_settlement?
  end
end
