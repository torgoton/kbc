require_relative "goal_test_case"

class Scoring::Goals::ScoutsTest < Scoring::Goals::GoalTestCase
  def score(ctx) = Scoring::Goals::Scouts.new(ctx[:game]).score_for(ctx[:chris])[:score]

  # Board 1 row 7 "WSCFWLDDCW": (7,2)=C, (7,3)=F, (7,4)=W, (7,5)=L
  test "1 per settlement next to but not on the removed terrain" do
    ctx = build_game(chris_settlements: [ [ 7, 3 ], [ 7, 4 ], [ 0, 0 ] ])
    ctx[:game].removed_terrain = "W"
    # (7,3) F is next to (7,4) W: scores. (7,4) is on W: no.
    assert_equal 1, score(ctx)
  end

  test "0 when nothing removed" do
    assert_equal 0, score(build_game(chris_settlements: [ [ 7, 3 ] ]))
  end

  test "starting a game with scouts removes one terrain from the deck" do
    game = games(:game2player)
    game.goals = [ "scouts" ]
    game.move_count = 0
    game.send(:initialize_terrain_deck)

    assert_includes %w[C D F G T], game.removed_terrain
    all = game.deck + game.discard
    assert_equal 20, all.size
    assert_not_includes all, game.removed_terrain
    assert_equal "scouts_terrain", game.moves.where(action: "scouts_terrain").first.action
  end

  test "without scouts the full deck is used" do
    game = games(:game2player)
    game.goals = [ "hermits" ]
    game.send(:initialize_terrain_deck)

    assert_nil game.removed_terrain
    assert_equal 25, (game.deck + game.discard).size
  end
end
