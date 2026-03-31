require_relative "goal_test_case"

class Scoring::Goals::WorkersTest < Scoring::Goals::GoalTestCase
  # OasisBoard row 7: "WSCFWLDDCW"
  #   (7,1)=S(castle), (7,5)=L
  # (7,2) is adjacent to castle (7,1) → scores
  # (7,4) is adjacent to L at (7,5) → scores
  # (0,0) has no S or L neighbors → 0

  test "1 point per settlement adjacent to a castle or location space" do
    # (7,2) adj to S(castle) at (7,1); (7,4) adj to L at (7,5)
    ctx = build_game(chris_settlements: [ [ 7, 2 ], [ 7, 4 ] ])
    result = Scoring::Goals::Workers.new(ctx[:game]).score_for(ctx[:chris])
    assert_equal 2, result[:score]
  end
end
