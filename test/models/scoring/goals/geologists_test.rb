require_relative "goal_test_case"

class Scoring::Goals::GeologistsTest < Scoring::Goals::GoalTestCase
  # Board 1 mountains: area A includes (3,10); area B includes (3,12); (3,11) is Canyon between them.
  test "0 when settlements touch only one mountain area" do
    ctx = build_game(chris_settlements: [ [ 1, 9 ] ])
    assert_equal 0, Scoring::Goals::Geologists.new(ctx[:game]).score_for(ctx[:chris])[:score]
  end

  test "2 per mountain area connected by one settlement group" do
    ctx = build_game(chris_settlements: [ [ 3, 11 ] ])
    assert_equal 4, Scoring::Goals::Geologists.new(ctx[:game]).score_for(ctx[:chris])[:score]
  end

  test "an area touched by two settlements of the same group scores once" do
    ctx = build_game(chris_settlements: [ [ 3, 11 ], [ 4, 11 ] ])
    assert_equal 4, Scoring::Goals::Geologists.new(ctx[:game]).score_for(ctx[:chris])[:score]
  end

  test "separate groups touching different areas do not connect" do
    ctx = build_game(chris_settlements: [ [ 1, 9 ], [ 6, 17 ] ])
    assert_equal 0, Scoring::Goals::Geologists.new(ctx[:game]).score_for(ctx[:chris])[:score]
  end
end
