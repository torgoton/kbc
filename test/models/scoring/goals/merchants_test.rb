require_relative "goal_test_case"

class Scoring::Goals::MerchantsTest < Scoring::Goals::GoalTestCase
  # OasisBoard row 7: "WSCFWLDDCW"
  #   (7,1)=S(castle), (7,2)=C, (7,3)=F, (7,4)=W, (7,5)=L
  # Chain (7,2)-(7,3)-(7,4): adj to castle (7,1) and L-terrain (7,5) → 4×2 = 8

  test "0 when component touches fewer than 2 special hexes" do
    # (7,2) is adjacent only to castle (7,1)
    ctx = build_game(chris_settlements: [ [ 7, 2 ] ])
    result = Scoring::Goals::Merchants.new(ctx[:game]).score_for(ctx[:chris])
    assert_equal 0, result[:score]
  end

  test "4 per special hex when component touches 2 or more" do
    ctx = build_game(chris_settlements: [ [ 7, 2 ], [ 7, 3 ], [ 7, 4 ] ])
    result = Scoring::Goals::Merchants.new(ctx[:game]).score_for(ctx[:chris])
    assert_equal 8, result[:score]
  end

  test "isolated component with no special hexes scores 0" do
    ctx = build_game(chris_settlements: [ [ 0, 0 ], [ 7, 2 ], [ 7, 3 ], [ 7, 4 ] ])
    result = Scoring::Goals::Merchants.new(ctx[:game]).score_for(ctx[:chris])
    assert_equal 8, result[:score]
  end
end
