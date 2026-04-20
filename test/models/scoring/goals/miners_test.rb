require_relative "goal_test_case"

class Scoring::Goals::MinersTest < Scoring::Goals::GoalTestCase
  # Using Tower as board index 1 (global cols 10-19, rows 0-9)
  # Tower row 0: "TTTTMMGMCC" → M at local (0,4),(0,5),(0,7) → global (0,14),(0,15),(0,17)
  # Tower row 1: "TMTTFGMMMC" → M at local (1,6),(1,7),(1,8) → global (1,16),(1,17),(1,18)
  #
  # Neighbors of global (0,13) [even row]: (0,12),(0,14),(1,12),(1,13) — (0,14) is M → qualifies
  # Neighbors of global (0,14) [even row]: (0,13),(0,15),(1,13),(1,14) — (0,15) is M → on M, does not score

  TOWER_BOARDS = [ [ 1, 0 ], [ 3, 0 ], [ 0, 0 ], [ 4, 0 ] ]

  def build_tower_game(chris_settlements: [], paula_settlements: [])
    build_game(chris_settlements: chris_settlements, paula_settlements: paula_settlements,
               boards: TOWER_BOARDS)
  end

  test "1 point per settlement adjacent to mountain terrain" do
    # global (0,13) is adjacent to M at (0,14)
    ctx = build_tower_game(chris_settlements: [ [ 0, 13 ] ])
    result = Scoring::Goals::Miners.new(ctx[:game]).score_for(ctx[:chris])
    assert_equal 1, result[:score]
  end
end
