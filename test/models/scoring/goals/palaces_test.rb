require_relative "goal_test_case"

class Scoring::Goals::PalacesTest < Scoring::Goals::GoalTestCase
  # Board 16 (Temple) has a Palace at local (2,2); as the first section that is global (2,2).
  BOARDS = [ [ 16, 0 ], [ 1, 0 ], [ 0, 0 ], [ 4, 0 ] ]

  def score(ctx, who = :chris) = Scoring::Goals::Palaces.new(ctx[:game]).score_for(ctx[who])[:score]

  test "0 with no adjacent settlement" do
    assert_equal 0, score(build_game(boards: BOARDS, chris_settlements: [ [ 0, 0 ] ]))
  end

  test "5 for a palace where you have the most adjacent settlements" do
    ctx = build_game(boards: BOARDS, chris_settlements: [ [ 2, 1 ], [ 2, 3 ] ], paula_settlements: [ [ 1, 2 ] ])
    assert_equal 5, score(ctx)
    assert_equal 0, score(ctx, :paula)
  end

  test "0 when Noblewomen is also a goal (it already scores palaces)" do
    ctx = build_game(boards: BOARDS, goals: [ "noblewomen" ], chris_settlements: [ [ 2, 1 ] ])
    assert_equal 0, score(ctx)
    assert_equal 5, Scoring::Goals::Noblewomen.new(ctx[:game]).score_for(ctx[:chris])[:score]
  end

  test "ignores castles and other special hexes" do
    ctx = build_game(boards: BOARDS, chris_settlements: [ [ 7, 2 ] ])
    assert_equal 0, score(ctx)
  end
end
