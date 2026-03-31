require_relative "goal_test_case"

class Scoring::Goals::HermitsTest < Scoring::Goals::GoalTestCase
  test "1 point per connected component" do
    # (0,0) and (9,9) are far apart — 2 components
    ctx = build_game(chris_settlements: [ [ 0, 0 ], [ 9, 9 ] ])
    result = Scoring::Goals::Hermits.new(ctx[:game]).score_for(ctx[:chris])
    assert_equal 2, result[:score]
  end
end
