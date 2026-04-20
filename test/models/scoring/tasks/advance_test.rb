require_relative "../goals/goal_test_case"

class Scoring::Tasks::AdvanceTest < Scoring::Goals::GoalTestCase
  test "9 points for 7 settlements on the top edge" do
    ctx = build_game(chris_settlements: 7.times.map { |i| [ 0, i ] }, goals: [ "advance" ])
    result = Scoring::Tasks::Advance.new(ctx[:game]).score_for(ctx[:chris])
    assert_equal 9, result[:score]
  end

  test "9 points for 7 settlements on the bottom edge" do
    ctx = build_game(chris_settlements: 7.times.map { |i| [ 19, i ] }, goals: [ "advance" ])
    result = Scoring::Tasks::Advance.new(ctx[:game]).score_for(ctx[:chris])
    assert_equal 9, result[:score]
  end

  test "9 points for 7 settlements on the left edge" do
    ctx = build_game(chris_settlements: 7.times.map { |i| [ i, 0 ] }, goals: [ "advance" ])
    result = Scoring::Tasks::Advance.new(ctx[:game]).score_for(ctx[:chris])
    assert_equal 9, result[:score]
  end

  test "9 points for 7 settlements on the right edge" do
    ctx = build_game(chris_settlements: 7.times.map { |i| [ i, 19 ] }, goals: [ "advance" ])
    result = Scoring::Tasks::Advance.new(ctx[:game]).score_for(ctx[:chris])
    assert_equal 9, result[:score]
  end

  test "9 points for 7 non-contiguous settlements on an edge" do
    scattered = [ [ 0, 0 ], [ 0, 3 ], [ 0, 5 ], [ 0, 8 ], [ 0, 11 ], [ 0, 15 ], [ 0, 19 ] ]
    ctx = build_game(chris_settlements: scattered, goals: [ "advance" ])
    result = Scoring::Tasks::Advance.new(ctx[:game]).score_for(ctx[:chris])
    assert_equal 9, result[:score]
  end

  test "0 points for only 6 settlements on any edge" do
    ctx = build_game(chris_settlements: 6.times.map { |i| [ 0, i ] }, goals: [ "advance" ])
    result = Scoring::Tasks::Advance.new(ctx[:game]).score_for(ctx[:chris])
    assert_equal 0, result[:score]
  end

  test "0 points with no settlements" do
    ctx = build_game(chris_settlements: [], goals: [ "advance" ])
    result = Scoring::Tasks::Advance.new(ctx[:game]).score_for(ctx[:chris])
    assert_equal 0, result[:score]
  end

  test "flat 9 when multiple edges qualify" do
    top = 7.times.map { |i| [ 0, i ] }
    bottom = 7.times.map { |i| [ 19, i ] }
    ctx = build_game(chris_settlements: (top + bottom).uniq, goals: [ "advance" ])
    result = Scoring::Tasks::Advance.new(ctx[:game]).score_for(ctx[:chris])
    assert_equal 9, result[:score]
  end
end
