require_relative "goal_test_case"

class Scoring::Goals::AmbassadorsTest < Scoring::Goals::GoalTestCase
  test "returns 0 when bonus_scores has no ambassadors entry" do
    ctx = build_game
    result = Scoring::Goals::Ambassadors.new(ctx[:game]).score_for(ctx[:chris])
    assert_equal 0, result[:score]
  end

  test "returns accumulated bonus_scores ambassadors value" do
    ctx = build_game
    ctx[:chris].update!(bonus_scores: { "ambassadors" => 3 })
    result = Scoring::Goals::Ambassadors.new(ctx[:game]).score_for(ctx[:chris])
    assert_equal 3, result[:score]
  end
end
