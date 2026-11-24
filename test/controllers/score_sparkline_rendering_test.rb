require "test_helper"

class ScoreSparklineRenderingTest < ActionView::TestCase
  def started_game
    game = Game.create!(state: "waiting")
    game.add_player(users(:chris))
    game.add_player(users(:paula))
    game.start
    game.reload.tap(&:instantiate)
  end

  test "common resources shows no chart before a round completes" do
    assert_no_match "score-sparkline", render("games/common_resources", game: started_game)
  end

  test "common resources shows the chart once a round has completed" do
    game = started_game
    last = game.game_players.max_by(&:order)
    game.moves.create!(order: 1, game_player: last, action: "end_turn", deliberate: true, reversible: false,
                       scores_after: { "0" => 1, "1" => 2 })

    assert_match "score-sparkline", render("games/common_resources", game: game)
  end
end
