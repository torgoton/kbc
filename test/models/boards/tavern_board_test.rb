require "test_helper"

class TavernBoardTest < ActiveSupport::TestCase
  test "terrain_at returns correct terrain for known positions" do
    board = Boards::TavernBoard.new(0)
    assert_equal "F", board.terrain_at(0, 0)  # row 0: "FDDMMDDCCC"
    assert_equal "L", board.terrain_at(6, 2)  # row 6: "DFLCWTTLCG" — location hex
    assert_equal "S", board.terrain_at(3, 3)  # row 3: "WWFSGGTTMM" — Castle (S)
  end

  test "location_hexes returns two Tavern tile spawn positions" do
    board = Boards::TavernBoard.new(0)
    assert_equal [ { r: 6, c: 2, k: "Tavern" }, { r: 6, c: 7, k: "Tavern" } ], board.location_hexes
  end

  test "scoring_hexes returns the Castle scoring hex" do
    board = Boards::TavernBoard.new(0)
    assert_equal [ { r: 3, c: 3, k: "Castle" } ], board.scoring_hexes
  end
end
