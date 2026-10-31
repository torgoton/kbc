require_relative "goal_test_case"

class Scoring::Goals::RangersTest < Scoring::Goals::GoalTestCase
  def score(settlements, paula: [])
    ctx = build_game(chris_settlements: settlements, paula_settlements: paula)
    Scoring::Goals::Rangers.new(ctx[:game]).score_for(ctx[:chris])[:score]
  end

  test "0 with no settlements" do
    assert_equal 0, score([])
  end

  test "2 for each row holding exactly one settlement" do
    assert_equal 6, score([ [ 2, 3 ], [ 5, 9 ], [ 11, 0 ] ])
  end

  test "a row with two or more settlements scores nothing" do
    assert_equal 2, score([ [ 2, 3 ], [ 2, 4 ], [ 2, 12 ], [ 7, 7 ] ])
  end

  test "a row spans both board sections, and opponents' settlements are ignored" do
    assert_equal 2, score([ [ 4, 3 ] ], paula: [ [ 4, 15 ] ])
    assert_equal 0, score([ [ 4, 3 ], [ 4, 15 ] ])
  end
end
