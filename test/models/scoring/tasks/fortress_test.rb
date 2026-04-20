require_relative "../goals/goal_test_case"

class Scoring::Tasks::FortressTest < Scoring::Goals::GoalTestCase
  CENTER = [ 5, 5 ].freeze
  # (5, 5) is on an odd row, so its six neighbors are:
  RING = [ [ 5, 4 ], [ 5, 6 ], [ 4, 5 ], [ 4, 6 ], [ 6, 5 ], [ 6, 6 ] ].freeze

  test "6 points when a settlement is surrounded by 6 of your settlements" do
    chris_settlements = [ CENTER ] + RING
    ctx = build_game(chris_settlements: chris_settlements, goals: [ "fortress" ])
    result = Scoring::Tasks::Fortress.new(ctx[:game]).score_for(ctx[:chris])
    assert_equal 6, result[:score]
  end

  test "0 points when no settlements are placed" do
    ctx = build_game(chris_settlements: [], goals: [ "fortress" ])
    result = Scoring::Tasks::Fortress.new(ctx[:game]).score_for(ctx[:chris])
    assert_equal 0, result[:score]
  end

  test "0 points when only 5 of 6 neighbors are own settlements" do
    chris_settlements = [ CENTER ] + RING.first(5)
    ctx = build_game(chris_settlements: chris_settlements, goals: [ "fortress" ])
    result = Scoring::Tasks::Fortress.new(ctx[:game]).score_for(ctx[:chris])
    assert_equal 0, result[:score]
  end

  test "0 points when one neighbor is an opponent's settlement" do
    chris_settlements = [ CENTER ] + RING.first(5)
    paula_settlements = [ RING.last ]
    ctx = build_game(chris_settlements: chris_settlements, paula_settlements: paula_settlements, goals: [ "fortress" ])
    result = Scoring::Tasks::Fortress.new(ctx[:game]).score_for(ctx[:chris])
    assert_equal 0, result[:score]
  end

  test "0 points for an edge settlement that cannot have 6 neighbors" do
    # (0, 5) is on row 0 so two of its six offsets land at row -1 and are dropped.
    edge_center = [ 0, 5 ]
    edge_ring = [ [ 0, 4 ], [ 0, 6 ], [ 1, 4 ], [ 1, 5 ] ]
    ctx = build_game(chris_settlements: [ edge_center ] + edge_ring, goals: [ "fortress" ])
    result = Scoring::Tasks::Fortress.new(ctx[:game]).score_for(ctx[:chris])
    assert_equal 0, result[:score]
  end

  test "flat 6 when multiple fortresses qualify" do
    second_center = [ 15, 15 ]
    second_ring = [ [ 15, 14 ], [ 15, 16 ], [ 14, 15 ], [ 14, 16 ], [ 16, 15 ], [ 16, 16 ] ]
    chris_settlements = [ CENTER ] + RING + [ second_center ] + second_ring
    ctx = build_game(chris_settlements: chris_settlements, goals: [ "fortress" ])
    result = Scoring::Tasks::Fortress.new(ctx[:game]).score_for(ctx[:chris])
    assert_equal 6, result[:score]
  end
end
