require_relative "goal_test_case"

class Scoring::Goals::CitizensTest < Scoring::Goals::GoalTestCase
  test "floor(largest component size / 2)" do
    # 3 connected settlements → floor(3/2) = 1
    ctx = build_game(chris_settlements: [ [ 7, 2 ], [ 7, 3 ], [ 7, 4 ] ])
    result = Scoring::Goals::Citizens.new(ctx[:game]).score_for(ctx[:chris])
    assert_equal 1, result[:score]
  end
end
