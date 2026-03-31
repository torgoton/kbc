require_relative "goal_test_case"

class Scoring::Goals::FishermenTest < Scoring::Goals::GoalTestCase
  # OasisBoard row 3: "WWWFGTFFFF" — (3,3)=F; odd-row neighbor (3,2)=W
  # OasisBoard row 8: "WWCFWWWDDW" — (8,3)=F
  # (0,7)=G on OasisBoard; even-row neighbors (0,6)=T,(0,8)=G,(1,6)=T,(1,7)=T — no W
  # (3,0)=W on OasisBoard — on water

  test "0 when no settlement is adjacent to water" do
    ctx = build_game(chris_settlements: [ [ 0, 7 ] ])
    result = Scoring::Goals::Fishermen.new(ctx[:game]).score_for(ctx[:chris])
    assert_equal 0, result[:score]
  end

  test "1 for a non-water settlement adjacent to water" do
    ctx = build_game(chris_settlements: [ [ 3, 3 ] ])
    result = Scoring::Goals::Fishermen.new(ctx[:game]).score_for(ctx[:chris])
    assert_equal 1, result[:score]
  end

  test "0 for a settlement on water terrain" do
    ctx = build_game(chris_settlements: [ [ 3, 0 ] ])
    result = Scoring::Goals::Fishermen.new(ctx[:game]).score_for(ctx[:chris])
    assert_equal 0, result[:score]
  end

  test "counts all qualifying settlements" do
    ctx = build_game(chris_settlements: [ [ 3, 3 ], [ 8, 3 ] ])
    result = Scoring::Goals::Fishermen.new(ctx[:game]).score_for(ctx[:chris])
    assert_equal 2, result[:score]
  end
end
