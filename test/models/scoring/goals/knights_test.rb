require_relative "goal_test_case"

class Scoring::Goals::KnightsTest < Scoring::Goals::GoalTestCase
  test "0 with no settlements" do
    ctx = build_game
    result = Scoring::Goals::Knights.new(ctx[:game]).score_for(ctx[:chris])
    assert_equal 0, result[:score]
  end

  test "2× the count on the single best row" do
    # 3 settlements on row 5 → score = 6
    ctx = build_game(chris_settlements: [ [ 5, 0 ], [ 5, 2 ], [ 5, 4 ] ])
    result = Scoring::Goals::Knights.new(ctx[:game]).score_for(ctx[:chris])
    assert_equal 6, result[:score]
  end

  test "scores only one row when rows are tied" do
    # 2 on row 5 and 2 on row 8 → score = 4, not 8
    ctx = build_game(chris_settlements: [ [ 5, 0 ], [ 5, 2 ], [ 8, 3 ], [ 8, 7 ] ])
    result = Scoring::Goals::Knights.new(ctx[:game]).score_for(ctx[:chris])
    assert_equal 4, result[:score]
  end
end
