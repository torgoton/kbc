require_relative "goal_test_case"

class Scoring::Goals::ChainersTest < Scoring::Goals::GoalTestCase
  # Row 10 is even: (10,5) touches (10,4) and (10,6); (10,3) and (10,7) are two hexes away.
  def score(settlements, paula: [])
    ctx = build_game(chris_settlements: settlements, paula_settlements: paula)
    Scoring::Goals::Chainers.new(ctx[:game]).score_for(ctx[:chris])[:score]
  end

  test "0 with no settlements or a lone settlement" do
    assert_equal 0, score([])
    assert_equal 0, score([ [ 10, 5 ] ])
  end

  test "the middle of a line of 3 scores 1; its ends touch only one" do
    assert_equal 1, score([ [ 10, 4 ], [ 10, 5 ], [ 10, 6 ] ])
  end

  test "a line of 5 scores for its 3 inner settlements" do
    assert_equal 3, score((3..7).map { |c| [ 10, c ] })
  end

  test "a closed triangle scores for all 3" do
    assert_equal 3, score([ [ 10, 5 ], [ 10, 6 ], [ 11, 5 ] ])
  end

  test "a settlement with 3 neighbours scores nothing" do
    # (10,5) touches (10,4), (10,6) and (9,4): it does not score; (10,4) and (9,4) each touch exactly 2.
    assert_equal 2, score([ [ 10, 5 ], [ 10, 4 ], [ 10, 6 ], [ 9, 4 ] ])
  end

  test "opponents' settlements do not count as neighbours" do
    assert_equal 0, score([ [ 10, 5 ], [ 10, 4 ] ], paula: [ [ 10, 6 ] ])
  end
end
