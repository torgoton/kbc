require_relative "goal_test_case"

class Scoring::Goals::MessengersTest < Scoring::Goals::GoalTestCase
  def score(ctx) = Scoring::Goals::Messengers.new(ctx[:game]).score_for(ctx[:chris])[:score]

  test "0 with no settlements" do
    assert_equal 0, score(build_game)
  end

  test "single settlement is a path of 1 hex" do
    assert_equal 2, score(build_game(chris_settlements: [ [ 0, 0 ] ]))
  end

  test "2 per hex of a straight chain, ends included" do
    assert_equal 8, score(build_game(chris_settlements: [ [ 7, 2 ], [ 7, 3 ], [ 7, 4 ], [ 7, 5 ] ]))
  end

  test "only the longest group counts" do
    ctx = build_game(chris_settlements: [ [ 0, 0 ], [ 0, 1 ], [ 9, 9 ], [ 9, 8 ], [ 9, 7 ] ])
    assert_equal 6, score(ctx)
  end

  test "a branching group scores its longest shortest path, not all hexes" do
    ctx = build_game(chris_settlements: [ [ 7, 2 ], [ 7, 3 ], [ 7, 4 ], [ 6, 3 ], [ 8, 3 ] ])
    result = score(ctx)
    assert_operator result, :<, 10
    assert_operator result, :>=, 6
  end
end
