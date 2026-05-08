require "test_helper"

class Turn::Consequences::GameCompletedTest < ActiveSupport::TestCase
  def setup
    @game = games(:game2player)
    @game.state = "playing"
    @game.scores = nil
  end

  test "apply! sets game.state to completed" do
    Turn::Consequences::GameCompleted.new(prior_state: "playing", prior_scores: nil).apply!(@game)
    assert_equal "completed", @game.state
  end

  test "apply! computes and assigns scores" do
    Turn::Consequences::GameCompleted.new(prior_state: "playing", prior_scores: nil).apply!(@game)
    refute_nil @game.scores
  end

  test "unapply! restores prior state and scores" do
    c = Turn::Consequences::GameCompleted.new(prior_state: "playing", prior_scores: { "x" => 1 })
    @game.scores = { "x" => 1 }
    c.apply!(@game)
    c.unapply!(@game)
    assert_equal "playing", @game.state
    assert_equal({ "x" => 1 }, @game.scores)
  end

  test "to_h round-trips through from_h" do
    c = Turn::Consequences::GameCompleted.new(prior_state: "playing", prior_scores: nil)
    assert_equal "game_completed", c.to_h["type"]
    assert_equal c, Turn::Consequences::GameCompleted.from_h(c.to_h)
  end

  test "factory dispatches by type" do
    c = Turn::Consequences::GameCompleted.new(prior_state: "playing", prior_scores: nil)
    assert_equal c, Turn::Consequences.from_h(c.to_h)
  end
end
