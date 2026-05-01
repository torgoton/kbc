require "test_helper"

class CrossroadsTileTest < ActiveSupport::TestCase
  test "CrossroadsTile is not activatable" do
    assert_not Tiles::CrossroadsTile.new(1).activatable?(player_order: 0, board_contents: nil, board: nil)
  end

  test "CrossroadsTile has crossroads_tile? true" do
    assert Tiles::CrossroadsTile.new(1).crossroads_tile?
  end

  test "base Tile returns false for crossroads_tile?" do
    assert_not Tiles::FarmTile.new(1).crossroads_tile?
  end
end
