require "test_helper"

class Turn::Consequences::OutpostDeactivatedTest < ActiveSupport::TestCase
  def setup
    @game = games(:game2player)
    @game.current_action = { "turn" => { "outpost_active" => true } }
  end

  test "apply! sets current_action.turn.outpost_active to false" do
    Turn::Consequences::OutpostDeactivated.new(prior_active: true).apply!(@game)
    assert_equal false, @game.current_action.dig("turn", "outpost_active")
  end

  test "unapply! restores prior_active" do
    c = Turn::Consequences::OutpostDeactivated.new(prior_active: true)
    c.apply!(@game)
    c.unapply!(@game)
    assert_equal true, @game.current_action.dig("turn", "outpost_active")
  end

  test "to_h round-trips through from_h" do
    c = Turn::Consequences::OutpostDeactivated.new(prior_active: true)
    assert_equal({ "type" => "outpost_deactivated", "prior_active" => true }, c.to_h)
    assert_equal c, Turn::Consequences::OutpostDeactivated.from_h(c.to_h)
  end

  test "factory dispatches by type" do
    c = Turn::Consequences::OutpostDeactivated.new(prior_active: true)
    assert_equal c, Turn::Consequences.from_h(c.to_h)
  end
end
