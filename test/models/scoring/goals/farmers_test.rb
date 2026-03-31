require_relative "goal_test_case"

class Scoring::Goals::FarmersTest < Scoring::Goals::GoalTestCase
  # Board layout: [Oasis(0), Paddock(0), Farm(0), Tavern(0)]
  # Quadrant offsets: i=0 rows 0-9 cols 0-9, i=1 rows 0-9 cols 10-19,
  #                   i=2 rows 10-19 cols 0-9, i=3 rows 10-19 cols 10-19

  test "0 with no settlements" do
    ctx = build_game
    result = Scoring::Goals::Farmers.new(ctx[:game]).score_for(ctx[:chris])
    assert_equal 0, result[:score]
  end

  test "3 points per settlement in the quadrant with the fewest" do
    # 3 in quadrant 0, 2 in quadrant 1, 1 in quadrant 2, 0 in quadrant 3
    # fewest = 0 (quadrant 3) → 0 × 3 = 0
    ctx = build_game(chris_settlements: [
      [ 0, 0 ], [ 1, 0 ], [ 2, 0 ],   # quadrant 0: 3
      [ 0, 10 ], [ 1, 10 ],            # quadrant 1: 2
      [ 10, 0 ]                        # quadrant 2: 1
    ])
    result = Scoring::Goals::Farmers.new(ctx[:game]).score_for(ctx[:chris])
    assert_equal 0, result[:score]
  end

  test "scores the quadrant with fewest settlements when all quadrants occupied" do
    # 3 in quadrant 0, 2 in quadrant 1, 1 in quadrant 2, 4 in quadrant 3
    # fewest = 1 (quadrant 2) → 1 × 3 = 3
    ctx = build_game(chris_settlements: [
      [ 0, 0 ], [ 1, 0 ], [ 2, 0 ],           # quadrant 0: 3
      [ 0, 10 ], [ 1, 10 ],                    # quadrant 1: 2
      [ 10, 0 ],                               # quadrant 2: 1
      [ 10, 10 ], [ 11, 10 ], [ 12, 10 ], [ 13, 10 ] # quadrant 3: 4
    ])
    result = Scoring::Goals::Farmers.new(ctx[:game]).score_for(ctx[:chris])
    assert_equal 3, result[:score]
  end

  test "does not count opponent settlements" do
    # chris: 2 in each quadrant → fewest = 2 → 2 × 3 = 6
    # paula settlements in other quadrants should not affect chris score
    ctx = build_game(
      chris_settlements: [
        [ 0, 0 ], [ 1, 0 ],     # quadrant 0: 2
        [ 0, 10 ], [ 1, 10 ],   # quadrant 1: 2
        [ 10, 0 ], [ 11, 0 ],   # quadrant 2: 2
        [ 10, 10 ], [ 11, 10 ]  # quadrant 3: 2
      ],
      paula_settlements: [ [ 5, 5 ], [ 5, 6 ], [ 5, 7 ] ]
    )
    result = Scoring::Goals::Farmers.new(ctx[:game]).score_for(ctx[:chris])
    assert_equal 6, result[:score]
  end
end
