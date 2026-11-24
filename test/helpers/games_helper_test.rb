require "test_helper"

class GamesHelperTest < ActionView::TestCase
  test "clock_display formats ms as M:SS, matching the JS clock controller" do
    assert_equal "5:00", clock_display(300_000)
    assert_equal "0:07", clock_display(7_000)
    assert_equal "1:05", clock_display(65_000)
  end

  test "clock_display shows a leading minus once the clock has flagged" do
    assert_equal "-1:40", clock_display(-100_000)
    assert_equal "0:00", clock_display(0)
  end

  FakeGame = Struct.new(:score_history, :game_players)
  FakePlayer = Struct.new(:order)

  def sparkline_game(history)
    FakeGame.new(history, [ FakePlayer.new(0), FakePlayer.new(1) ])
  end

  test "score_sparkline renders nothing before the first round completes" do
    assert_nil score_sparkline(sparkline_game([]))
  end

  test "score_sparkline draws one polyline per player in the player color" do
    html = score_sparkline(sparkline_game([ { "0" => 4, "1" => 2 } ]))

    assert_equal 2, html.scan("<polyline").size
    assert_includes html, %(stroke="#{player_color(0)}")
    assert_includes html, %(stroke="#{player_color(1)}")
  end

  test "score_sparkline puts the highest score at the top and starts every line at zero" do
    html = score_sparkline(sparkline_game([ { "0" => 10, "1" => 5 } ]))
    points = html.scan(/points="([^"]+)"/).flatten.map { |p| p.split.map { |xy| xy.split(",").map(&:to_f) } }

    top_y = points.flat_map { |line| line.map(&:last) }.min
    assert_equal points[0].last.last, top_y # player 0 holds the max score
    assert_operator points[1].last.last, :>, top_y
    assert_equal points[0].first.last, points[1].first.last # shared zero baseline
  end
end
