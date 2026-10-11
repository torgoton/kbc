require_relative "goal_test_case"

class Scoring::Goals::CaptainsTest < Scoring::Goals::GoalTestCase
  def score(ctx) = Scoring::Goals::Captains.new(ctx[:game]).score_for(ctx[:chris])[:score]

  test "settlement with 3 own neighbors scores" do
    center = [ 5, 5 ]
    ring = build_game.then { |c| c[:game].board_contents.neighbors(*center) }
    ctx = build_game(chris_settlements: [ center ] + ring.first(3))
    assert_equal 1, score(ctx)
  end

  test "full ring scores all 7 (ring members touch center + 2 ring neighbors)" do
    center = [ 5, 5 ]
    ring = build_game.then { |c| c[:game].board_contents.neighbors(*center) }
    ctx = build_game(chris_settlements: [ center ] + ring)
    assert_equal 7, score(ctx)
  end

  test "2 neighbors is not enough" do
    ring = build_game.then { |c| c[:game].board_contents.neighbors(5, 5) }
    assert_equal 0, score(build_game(chris_settlements: [ [ 5, 5 ] ] + ring.first(2)))
  end

  test "opponent settlements do not count" do
    ring = build_game.then { |c| c[:game].board_contents.neighbors(5, 5) }
    assert_equal 0, score(build_game(chris_settlements: [ [ 5, 5 ] ], paula_settlements: ring.first(3)))
  end
end
