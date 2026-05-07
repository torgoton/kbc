require "test_helper"

class Turn::Consequences::MandatoryRemainingDecrementedTest < ActiveSupport::TestCase
  def setup
    @game = games(:game2player)
  end

  test "apply! decrements current_action.turn.mandatory_remaining" do
    @game.current_action = { "turn" => { "mandatory_remaining" => 3 } }
    Turn::Consequences::MandatoryRemainingDecremented.new(prior_remaining: 3).apply!(@game)
    assert_equal 2, @game.current_action.dig("turn", "mandatory_remaining")
  end

  test "apply! creates the turn key when missing" do
    @game.current_action = nil
    Turn::Consequences::MandatoryRemainingDecremented.new(prior_remaining: 3).apply!(@game)
    assert_equal 2, @game.current_action.dig("turn", "mandatory_remaining")
  end

  test "unapply! restores prior_remaining" do
    @game.current_action = { "turn" => { "mandatory_remaining" => 3 } }
    c = Turn::Consequences::MandatoryRemainingDecremented.new(prior_remaining: 3)
    c.apply!(@game)
    c.unapply!(@game)
    assert_equal 3, @game.current_action.dig("turn", "mandatory_remaining")
  end

  test "to_h round-trips through from_h" do
    c = Turn::Consequences::MandatoryRemainingDecremented.new(prior_remaining: 3)
    assert_equal({ "type" => "mandatory_remaining_decremented", "prior_remaining" => 3 }, c.to_h)
    assert_equal c, Turn::Consequences::MandatoryRemainingDecremented.from_h(c.to_h)
  end

  test "equality is by value" do
    a = Turn::Consequences::MandatoryRemainingDecremented.new(prior_remaining: 3)
    b = Turn::Consequences::MandatoryRemainingDecremented.new(prior_remaining: 3)
    assert_equal a, b
  end
end
