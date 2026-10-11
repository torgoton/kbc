require_relative "goal_test_case"

class Scoring::Goals::NoblewomenTest < Scoring::Goals::GoalTestCase
  # Board 1 (7,1)=S, (7,5)=L. (7,2) touches only the S; (7,4) touches only the L.
  def score(ctx, who = :chris) = Scoring::Goals::Noblewomen.new(ctx[:game]).score_for(ctx[who])[:score]

  test "0 with no adjacent settlements" do
    assert_equal 0, score(build_game(chris_settlements: [ [ 0, 0 ] ]))
  end

  test "5 per special hex where you have the most adjacent settlements" do
    ctx = build_game(chris_settlements: [ [ 7, 2 ], [ 7, 4 ] ])
    assert_equal 10, score(ctx)
  end

  test "opponent with more adjacent settlements takes the hex" do
    ctx = build_game(chris_settlements: [ [ 7, 2 ] ], paula_settlements: [ [ 7, 0 ], [ 6, 1 ] ])
    assert_equal 0, score(ctx)
    assert_equal 5, score(ctx, :paula)
  end

  test "Palaces are not included (the Palaces goal scores them)" do
    # Board 16 first: its Palace is at (2,2), and (2,1) touches nothing else special.
    ctx = build_game(boards: [ [ 16, 0 ], [ 1, 0 ], [ 0, 0 ], [ 4, 0 ] ], chris_settlements: [ [ 2, 1 ] ])
    assert_equal 0, score(ctx)
  end

  test "tie scores for both players" do
    ctx = build_game(chris_settlements: [ [ 7, 2 ] ], paula_settlements: [ [ 7, 0 ] ])
    assert_equal 5, score(ctx)
    assert_equal 5, score(ctx, :paula)
  end
end
