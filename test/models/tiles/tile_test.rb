require "test_helper"

# Tests for the Tile base class interface.
# Does not reference any subclass — subclass-specific behaviour lives in subclass tests.

class Tiles::TileTest < ActiveSupport::TestCase
  test "valid_destinations returns empty array" do
    assert_equal [], Tiles::Tile.new(0).valid_destinations(board_contents: BoardState.new, board: nil, player_order: 0)
  end

  test "selectable_settlements returns empty array" do
    assert_equal [], Tiles::Tile.new(0).selectable_settlements(player_order: 0, board_contents: BoardState.new, board: nil)
  end

  test "activatable? returns true" do
    assert Tiles::Tile.new(0).activatable?(player_order: 0, board_contents: BoardState.new, board: nil)
  end

  test "from_hash raises ArgumentError for unknown klass" do
    assert_raises(ArgumentError) { Tiles::Tile.from_hash("klass" => "BogusTimeTile") }
  end
end
