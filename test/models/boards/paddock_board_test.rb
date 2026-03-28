require "test_helper"

class PaddockBoardTest < ActiveSupport::TestCase
  test "terrain_at returns correct terrain for known positions" do
    board = Boards::PaddockBoard.new(0)
    assert_equal "C", board.terrain_at(0, 0)  # row 0: "CCCDDWDDDD"
    assert_equal "L", board.terrain_at(2, 8)  # row 2: "MMCMMWDDLF" — location hex
    assert_equal "S", board.terrain_at(7, 5)  # row 7: "GGTWGSGFGT" — Castle (S)
  end

  test "location_hexes returns two Paddock tile spawn positions" do
    board = Boards::PaddockBoard.new(0)
    assert_equal [ { r: 2, c: 8, k: "Paddock" }, { r: 6, c: 1, k: "Paddock" } ], board.location_hexes
  end

  test "scoring_hexes returns the Castle scoring hex" do
    board = Boards::PaddockBoard.new(0)
    assert_equal [ { r: 7, c: 5, k: "Castle" } ], board.scoring_hexes
  end
end
