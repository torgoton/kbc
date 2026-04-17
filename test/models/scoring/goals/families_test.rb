require_relative "goal_test_case"

class Scoring::Goals::FamiliesTest < Scoring::Goals::GoalTestCase
  test "returns 0 when bonus_scores has no families entry" do
    ctx = build_game
    result = Scoring::Goals::Families.new(ctx[:game]).score_for(ctx[:chris])
    assert_equal 0, result[:score]
  end

  test "returns accumulated bonus_scores families value" do
    ctx = build_game
    ctx[:chris].update!(bonus_scores: { "families" => 2 })
    result = Scoring::Goals::Families.new(ctx[:game]).score_for(ctx[:chris])
    assert_equal 2, result[:score]
  end
end
