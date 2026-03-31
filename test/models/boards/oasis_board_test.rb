require "test_helper"

class OasisBoardTest < ActiveSupport::TestCase
  test "terrain_at returns correct terrain for known positions" do
    board = Boards::OasisBoard.new(0)
    assert_equal "D", board.terrain_at(0, 0)  # row 0: "DDCWWTTGGG"
    assert_equal "L", board.terrain_at(2, 7)  # row 2: "DDWFFTTLFG" — location hex
    assert_equal "S", board.terrain_at(7, 1)  # row 7: "WSCFWLDDCW" — Castle (S)
  end

  test "location_hexes returns two Oasis tile spawn positions" do
    board = Boards::OasisBoard.new(0)
    assert_equal [ { r: 2, c: 7, k: "Oasis" }, { r: 7, c: 5, k: "Oasis" } ], board.location_hexes
  end

  test "scoring_hexes returns the Castle scoring hex" do
    board = Boards::OasisBoard.new(0)
    assert_equal [ { r: 7, c: 1, k: "Castle" } ], board.scoring_hexes
  end

  test "scoring_hexes flips coordinates when board is flipped" do
    board = Boards::OasisBoard.new(1)
    assert_equal [ { r: 2, c: 8, k: "Castle" } ], board.scoring_hexes
  end

  test "location_hexes flips coordinates when board is flipped" do
    board = Boards::OasisBoard.new(1)
    assert_equal [ { r: 7, c: 2, k: "Oasis" }, { r: 2, c: 4, k: "Oasis" } ], board.location_hexes
  end
end
