require_relative "goal_test_case"

class Scoring::Goals::DiscoverersTest < Scoring::Goals::GoalTestCase
  test "0 with no settlements" do
    ctx = build_game
    result = Scoring::Goals::Discoverers.new(ctx[:game]).score_for(ctx[:chris])
    assert_equal 0, result[:score]
  end

  test "1 point per row with at least one settlement" do
    ctx = build_game(chris_settlements: [ [ 3, 0 ], [ 3, 5 ], [ 7, 2 ] ])
    result = Scoring::Goals::Discoverers.new(ctx[:game]).score_for(ctx[:chris])
    assert_equal 2, result[:score]
  end

  test "multiple settlements on same row count as 1" do
    ctx = build_game(chris_settlements: [ [ 5, 0 ], [ 5, 2 ], [ 5, 4 ] ])
    result = Scoring::Goals::Discoverers.new(ctx[:game]).score_for(ctx[:chris])
    assert_equal 1, result[:score]
  end

  test "does not count opponent settlements" do
    ctx = build_game(chris_settlements: [ [ 3, 0 ] ], paula_settlements: [ [ 7, 2 ], [ 9, 1 ] ])
    result = Scoring::Goals::Discoverers.new(ctx[:game]).score_for(ctx[:chris])
    assert_equal 1, result[:score]
  end
end
