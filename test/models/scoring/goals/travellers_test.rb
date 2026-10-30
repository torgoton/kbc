require_relative "goal_test_case"

class Scoring::Goals::TravellersTest < Scoring::Goals::GoalTestCase
  def score(settlements)
    ctx = build_game(chris_settlements: settlements)
    Scoring::Goals::Travellers.new(ctx[:game]).score_for(ctx[:chris])[:score]
  end

  test "0 when no settlement is on the edge" do
    assert_equal 0, score([ [ 5, 5 ], [ 10, 10 ] ])
  end

  test "1 for each settlement on any of the four edges" do
    assert_equal 4, score([ [ 0, 7 ], [ 19, 7 ], [ 7, 0 ], [ 7, 19 ] ])
  end

  test "a corner settlement counts once" do
    assert_equal 1, score([ [ 0, 0 ] ])
  end

  test "an opponent's edge settlements do not count" do
    ctx = build_game(paula_settlements: [ [ 0, 7 ] ])
    assert_equal 0, Scoring::Goals::Travellers.new(ctx[:game]).score_for(ctx[:chris])[:score]
  end
end
