require_relative "../goals/goal_test_case"

class Scoring::Tasks::RoadTest < Scoring::Goals::GoalTestCase
  # NW-SE diagonal (constant cube-q = 4), verified via SE step offsets
  NW_SE_7 = [ [ 2, 5 ], [ 3, 5 ], [ 4, 6 ], [ 5, 6 ], [ 6, 7 ], [ 7, 7 ], [ 8, 8 ] ].freeze
  # NE-SW diagonal (constant cube-s = -9), verified via NE step offsets
  NE_SW_7 = [ [ 8, 5 ], [ 7, 5 ], [ 6, 6 ], [ 5, 6 ], [ 4, 7 ], [ 3, 7 ], [ 2, 8 ] ].freeze

  test "7 points for 7 settlements on a NW-SE diagonal" do
    ctx = build_game(chris_settlements: NW_SE_7, goals: [ "road" ])
    result = Scoring::Tasks::Road.new(ctx[:game]).score_for(ctx[:chris])
    assert_equal 7, result[:score]
  end

  test "7 points for 7 settlements on a NE-SW diagonal" do
    ctx = build_game(chris_settlements: NE_SW_7, goals: [ "road" ])
    result = Scoring::Tasks::Road.new(ctx[:game]).score_for(ctx[:chris])
    assert_equal 7, result[:score]
  end

  test "0 points for only 6 in a diagonal" do
    ctx = build_game(chris_settlements: NW_SE_7.first(6), goals: [ "road" ])
    result = Scoring::Tasks::Road.new(ctx[:game]).score_for(ctx[:chris])
    assert_equal 0, result[:score]
  end

  test "0 points when diagonal is broken by a gap" do
    broken = NW_SE_7.reject.with_index { |_, i| i == 3 }
    ctx = build_game(chris_settlements: broken, goals: [ "road" ])
    result = Scoring::Tasks::Road.new(ctx[:game]).score_for(ctx[:chris])
    assert_equal 0, result[:score]
  end

  test "0 points for 7 settlements in a horizontal row" do
    row7 = 7.times.map { |i| [ 5, i ] }
    ctx = build_game(chris_settlements: row7, goals: [ "road" ])
    result = Scoring::Tasks::Road.new(ctx[:game]).score_for(ctx[:chris])
    assert_equal 0, result[:score]
  end

  test "flat 7 when diagonal is longer than 7" do
    extra = [ 9, 8 ]
    ctx = build_game(chris_settlements: NW_SE_7 + [ extra ], goals: [ "road" ])
    result = Scoring::Tasks::Road.new(ctx[:game]).score_for(ctx[:chris])
    assert_equal 7, result[:score]
  end

  test "0 points for no settlements" do
    ctx = build_game(chris_settlements: [], goals: [ "road" ])
    result = Scoring::Tasks::Road.new(ctx[:game]).score_for(ctx[:chris])
    assert_equal 0, result[:score]
  end
end
