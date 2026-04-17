require_relative "goal_test_case"

class Scoring::Goals::ShepherdsTest < Scoring::Goals::GoalTestCase
  test "returns 0 when bonus_scores has no shepherds entry" do
    ctx = build_game
    result = Scoring::Goals::Shepherds.new(ctx[:game]).score_for(ctx[:chris])
    assert_equal 0, result[:score]
  end

  test "returns accumulated bonus_scores shepherds value" do
    ctx = build_game
    ctx[:chris].update!(bonus_scores: { "shepherds" => 4 })
    result = Scoring::Goals::Shepherds.new(ctx[:game]).score_for(ctx[:chris])
    assert_equal 4, result[:score]
  end
end
