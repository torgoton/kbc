require_relative "../goals/goal_test_case"

class Scoring::Tasks::CompassPointsTest < Scoring::Goals::GoalTestCase
  ALL_FOUR = [ [ 0, 5 ], [ 19, 5 ], [ 5, 0 ], [ 5, 19 ] ].freeze

  test "10 points when at least 1 settlement on each edge" do
    ctx = build_game(chris_settlements: ALL_FOUR, goals: [ "compass_points" ])
    result = Scoring::Tasks::CompassPoints.new(ctx[:game]).score_for(ctx[:chris])
    assert_equal 10, result[:score]
  end

  test "0 points when one edge is uncovered" do
    ctx = build_game(chris_settlements: ALL_FOUR.first(3), goals: [ "compass_points" ])
    result = Scoring::Tasks::CompassPoints.new(ctx[:game]).score_for(ctx[:chris])
    assert_equal 0, result[:score]
  end

  test "0 points with no settlements" do
    ctx = build_game(chris_settlements: [], goals: [ "compass_points" ])
    result = Scoring::Tasks::CompassPoints.new(ctx[:game]).score_for(ctx[:chris])
    assert_equal 0, result[:score]
  end

  test "corner settlement counts for two edges" do
    with_corner = [ [ 0, 0 ], [ 19, 5 ], [ 5, 19 ] ]
    ctx = build_game(chris_settlements: with_corner, goals: [ "compass_points" ])
    result = Scoring::Tasks::CompassPoints.new(ctx[:game]).score_for(ctx[:chris])
    assert_equal 10, result[:score]
  end
end
