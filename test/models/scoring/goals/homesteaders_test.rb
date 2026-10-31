require_relative "goal_test_case"

class Scoring::Goals::HomesteadersTest < Scoring::Goals::GoalTestCase
  def score(settlements, paula: [])
    ctx = build_game(chris_settlements: settlements, paula_settlements: paula)
    Scoring::Goals::Homesteaders.new(ctx[:game]).score_for(ctx[:chris])[:score]
  end

  test "0 with no settlements" do
    assert_equal 0, score([])
  end

  test "scores the settlements in the fullest section only" do
    # three in the top-left section, two in the top-right, one bottom-left
    assert_equal 3, score([ [ 1, 1 ], [ 2, 8 ], [ 9, 0 ], [ 3, 10 ], [ 4, 19 ], [ 15, 2 ] ])
  end

  test "sections are the four 10x10 quarters, including their edges" do
    assert_equal 2, score([ [ 9, 9 ], [ 0, 0 ], [ 10, 10 ], [ 19, 19 ] ])
    assert_equal 4, score([ [ 10, 10 ], [ 10, 19 ], [ 19, 10 ], [ 19, 19 ], [ 0, 0 ] ])
  end

  test "a tie between sections scores that count once" do
    assert_equal 2, score([ [ 1, 1 ], [ 2, 2 ], [ 12, 12 ], [ 13, 13 ] ])
  end

  test "opponents' settlements are ignored" do
    assert_equal 1, score([ [ 1, 1 ] ], paula: [ [ 2, 2 ], [ 3, 3 ] ])
  end
end
