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

  test "Swamp terrain can form a qualifying area" do
    # The first hidden section's row 1 is a lone strip of 8 Swamp hexes.
    ctx = build_game(
      boards: [ [ Boards::BoardSection::HIDDEN_SECTIONS.first, 0 ], [ 1, 0 ], [ 0, 0 ], [ 4, 0 ] ],
      chris_settlements: (1..8).map { |c| [ 1, c ] },
      goals: [ "home_country" ]
    )
    assert (1..8).all? { |c| ctx[:game].board_contents.terrain_at(1, c) == "B" }, "the strip is Swamp"
    result = Scoring::Tasks::HomeCountry.new(ctx[:game]).score_for(ctx[:chris])
    assert_equal 5, result[:score]
  end

  test "W and M terrain can form qualifying areas" do
    # [18, 1] is a 1-hex M island; score 5 confirms M participates.
    ctx = build_game(chris_settlements: [ [ 18, 1 ] ], goals: [ "home_country" ])
    result = Scoring::Tasks::HomeCountry.new(ctx[:game]).score_for(ctx[:chris])
    assert_equal 5, result[:score]
  end

  test "Farmland can form a qualifying area" do
    # Board 21's right edge (columns 8-9, rows 0-7) is one Farmland area.
    farmland = [ [ 0, 9 ], [ 1, 8 ], [ 1, 9 ], [ 2, 8 ], [ 2, 9 ], [ 3, 8 ], [ 3, 9 ], [ 4, 9 ],
                 [ 5, 8 ], [ 5, 9 ], [ 6, 8 ], [ 6, 9 ], [ 7, 8 ], [ 7, 9 ] ].map { |r, c| [ r, c + 10 ] }
    ctx = build_game(boards: [ [ 20, 0 ], [ 21, 0 ], [ 5, 0 ], [ 0, 0 ] ], chris_settlements: farmland, goals: [ "home_country" ])
    assert farmland.all? { |r, c| ctx[:game].board_contents.terrain_at(r, c) == "H" }, "the area is Farmland"
    result = Scoring::Tasks::HomeCountry.new(ctx[:game]).score_for(ctx[:chris])
    assert_equal 5, result[:score]
  end
end
