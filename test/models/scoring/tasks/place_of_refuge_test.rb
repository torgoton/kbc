require_relative "../goals/goal_test_case"

class Scoring::Tasks::PlaceOfRefugeTest < Scoring::Goals::GoalTestCase
  # With default BOARDS, section 1 (Oasis) is top-left. Its silver hex (S) is at (7,1).
  # Row 7 is odd, so neighbors use odd-row offsets: (7,0),(7,2),(6,1),(6,2),(8,1),(8,2).
  S_HEX = [ 7, 1 ].freeze
  S_RING = [ [ 7, 0 ], [ 7, 2 ], [ 6, 1 ], [ 6, 2 ], [ 8, 1 ], [ 8, 2 ] ].freeze

  # Section 1 also has a location hex (L) at (7,5).
  # Row 7 odd, neighbors: (7,4),(7,6),(6,5),(6,6),(8,5),(8,6).
  L_HEX = [ 7, 5 ].freeze
  L_RING = [ [ 7, 4 ], [ 7, 6 ], [ 6, 5 ], [ 6, 6 ], [ 8, 5 ], [ 8, 6 ] ].freeze

  test "8 points when a silver hex is surrounded by 6 own settlements" do
    ctx = build_game(chris_settlements: S_RING, goals: [ "place_of_refuge" ])
    result = Scoring::Tasks::PlaceOfRefuge.new(ctx[:game]).score_for(ctx[:chris])
    assert_equal 8, result[:score]
  end

  test "8 points when a location hex is surrounded by 6 own settlements" do
    ctx = build_game(chris_settlements: L_RING, goals: [ "place_of_refuge" ])
    result = Scoring::Tasks::PlaceOfRefuge.new(ctx[:game]).score_for(ctx[:chris])
    assert_equal 8, result[:score]
  end

  test "0 points when only 5 of 6 neighbors are own settlements" do
    ctx = build_game(chris_settlements: S_RING.first(5), goals: [ "place_of_refuge" ])
    result = Scoring::Tasks::PlaceOfRefuge.new(ctx[:game]).score_for(ctx[:chris])
    assert_equal 0, result[:score]
  end

  test "0 points when one neighbor is an opponent's settlement" do
    ctx = build_game(chris_settlements: S_RING.first(5), paula_settlements: [ S_RING.last ],
                     goals: [ "place_of_refuge" ])
    result = Scoring::Tasks::PlaceOfRefuge.new(ctx[:game]).score_for(ctx[:chris])
    assert_equal 0, result[:score]
  end

  test "0 points with no settlements" do
    ctx = build_game(chris_settlements: [], goals: [ "place_of_refuge" ])
    result = Scoring::Tasks::PlaceOfRefuge.new(ctx[:game]).score_for(ctx[:chris])
    assert_equal 0, result[:score]
  end

  test "flat 8 when multiple special hexes qualify" do
    ctx = build_game(chris_settlements: S_RING + L_RING, goals: [ "place_of_refuge" ])
    result = Scoring::Tasks::PlaceOfRefuge.new(ctx[:game]).score_for(ctx[:chris])
    assert_equal 8, result[:score]
  end
end
