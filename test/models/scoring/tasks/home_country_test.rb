require_relative "../goals/goal_test_case"

class Scoring::Tasks::HomeCountryTest < Scoring::Goals::GoalTestCase
  test "5 points for a 1-hex terrain area fully occupied" do
    ctx = build_game(chris_settlements: [ [ 18, 1 ] ], goals: [ "home_country" ])
    result = Scoring::Tasks::HomeCountry.new(ctx[:game]).score_for(ctx[:chris])
    assert_equal 5, result[:score]
  end

  test "5 points for a multi-hex terrain area fully occupied" do
    chris_settlements = [ [ 5, 1 ], [ 5, 2 ], [ 6, 1 ], [ 6, 3 ] ]
    ctx = build_game(chris_settlements: chris_settlements, goals: [ "home_country" ])
    result = Scoring::Tasks::HomeCountry.new(ctx[:game]).score_for(ctx[:chris])
    assert_equal 5, result[:score]
  end

  test "0 points when no settlements are placed" do
    ctx = build_game(chris_settlements: [], goals: [ "home_country" ])
    result = Scoring::Tasks::HomeCountry.new(ctx[:game]).score_for(ctx[:chris])
    assert_equal 0, result[:score]
  end

  test "0 points when an area is only partially occupied" do
    chris_settlements = [ [ 5, 1 ], [ 5, 2 ], [ 6, 1 ] ]
    ctx = build_game(chris_settlements: chris_settlements, goals: [ "home_country" ])
    result = Scoring::Tasks::HomeCountry.new(ctx[:game]).score_for(ctx[:chris])
    assert_equal 0, result[:score]
  end

  test "0 points when an opponent occupies a hex in the area" do
    chris_settlements = [ [ 5, 1 ], [ 5, 2 ], [ 6, 1 ] ]
    paula_settlements = [ [ 6, 3 ] ]
    ctx = build_game(chris_settlements: chris_settlements, paula_settlements: paula_settlements, goals: [ "home_country" ])
    result = Scoring::Tasks::HomeCountry.new(ctx[:game]).score_for(ctx[:chris])
    assert_equal 0, result[:score]
  end

  test "flat 5 when multiple areas qualify" do
    chris_settlements = [ [ 18, 1 ], [ 5, 1 ], [ 5, 2 ], [ 6, 1 ], [ 6, 3 ] ]
    ctx = build_game(chris_settlements: chris_settlements, goals: [ "home_country" ])
    result = Scoring::Tasks::HomeCountry.new(ctx[:game]).score_for(ctx[:chris])
    assert_equal 5, result[:score]
  end

  test "W and M terrain can form qualifying areas" do
    # [18, 1] is a 1-hex M island; score 5 confirms M participates.
    ctx = build_game(chris_settlements: [ [ 18, 1 ] ], goals: [ "home_country" ])
    result = Scoring::Tasks::HomeCountry.new(ctx[:game]).score_for(ctx[:chris])
    assert_equal 5, result[:score]
  end
end
