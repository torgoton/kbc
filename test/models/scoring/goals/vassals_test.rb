require_relative "goal_test_case"

class Scoring::Goals::VassalsTest < Scoring::Goals::GoalTestCase
  test "1 per settlement on a row or column beside an inner section edge" do
    ctx = build_game(chris_settlements: [ [ 9, 3 ], [ 10, 15 ], [ 4, 9 ], [ 15, 10 ] ])
    assert_equal 4, Scoring::Goals::Vassals.new(ctx[:game]).score_for(ctx[:chris])[:score]
  end

  test "outer-edge and interior settlements score 0" do
    ctx = build_game(chris_settlements: [ [ 0, 0 ], [ 19, 19 ], [ 5, 5 ], [ 8, 11 ] ])
    assert_equal 0, Scoring::Goals::Vassals.new(ctx[:game]).score_for(ctx[:chris])[:score]
  end
end
