require "test_helper"

class Turn::Consequences::GoalScoredTest < ActiveSupport::TestCase
  def setup
    @game = games(:game2player)
    @gp = @game.game_players.find { |g| g.order == 0 }
    @gp.bonus_scores = {}
  end

  test "apply! adds points to bonus_scores under the goal key" do
    Turn::Consequences::GoalScored.new(player: 0, goal: "treasure", points: 3, prior_score: 0).apply!(@game)
    assert_equal 3, @gp.bonus_scores["treasure"]
  end

  test "apply! accumulates onto an existing score" do
    @gp.bonus_scores = { "treasure" => 6 }
    Turn::Consequences::GoalScored.new(player: 0, goal: "treasure", points: 3, prior_score: 6).apply!(@game)
    assert_equal 9, @gp.bonus_scores["treasure"]
  end

  test "unapply! restores prior_score" do
    @gp.bonus_scores = { "treasure" => 6 }
    c = Turn::Consequences::GoalScored.new(player: 0, goal: "treasure", points: 3, prior_score: 6)
    c.apply!(@game)
    c.unapply!(@game)
    assert_equal 6, @gp.bonus_scores["treasure"]
  end

  test "unapply! removes the goal key when prior_score was 0" do
    c = Turn::Consequences::GoalScored.new(player: 0, goal: "treasure", points: 3, prior_score: 0)
    c.apply!(@game)
    c.unapply!(@game)
    refute @gp.bonus_scores.key?("treasure")
  end

  test "to_h round-trips through from_h" do
    c = Turn::Consequences::GoalScored.new(player: 0, goal: "treasure", points: 3, prior_score: 0)
    assert_equal({ "type" => "goal_scored", "player" => 0, "goal" => "treasure", "points" => 3, "prior_score" => 0 }, c.to_h)
    assert_equal c, Turn::Consequences::GoalScored.from_h(c.to_h)
  end

  test "factory dispatches by type" do
    c = Turn::Consequences::GoalScored.new(player: 0, goal: "treasure", points: 3, prior_score: 0)
    assert_equal c, Turn::Consequences.from_h(c.to_h)
  end
end
