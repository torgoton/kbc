require "test_helper"

class FarmBoardTest < ActiveSupport::TestCase
  test "terrain_at returns correct terrain for known positions (unflipped)" do
    board = Boards::FarmBoard.new(0)
    assert_equal "D", board.terrain_at(0, 0)  # row 0: "DDCWWTTTGG"
    assert_equal "L", board.terrain_at(1, 7)  # row 1: "DSCWTTTLGG" — location hex
    assert_equal "W", board.terrain_at(9, 9)  # row 9: "TTTWWWWWWW"
  end

  test "location_hexes returns two Farm tile spawn positions" do
    board = Boards::FarmBoard.new(0)
    assert_equal [ { r: 1, c: 7, k: "Farm" }, { r: 5, c: 2, k: "Farm" } ], board.location_hexes
  end

  test "scoring_hexes returns the Castle scoring hex" do
    board = Boards::FarmBoard.new(0)
    assert_equal [ { r: 1, c: 1, k: "Castle" } ], board.scoring_hexes
  end

  test "terrain_at reflects flipped layout (rows and columns reversed)" do
    board = Boards::FarmBoard.new(1)
    # Flipped = map.reverse.map(&:reverse)
    # Flipped row 0 = original row 9 reversed: "TTTWWWWWWW" → "WWWWWWWTTT"
    assert_equal "W", board.terrain_at(0, 0)
    # Flipped row 9 = original row 0 reversed: "DDCWWTTTGG" → "GGTTTTWCDD"
    assert_equal "D", board.terrain_at(9, 9)
  end
end
