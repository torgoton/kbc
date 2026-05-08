require "test_helper"

class Turn::Consequences::TurnResetTest < ActiveSupport::TestCase
  def setup
    @game = games(:game2player)
    @game.turn_number = 5
    @game.current_action = { "turn" => { "mandatory_remaining" => 2, "builds" => [ "[5, 5]" ] } }
  end

  test "apply! increments turn_number and clears the turn key" do
    Turn::Consequences::TurnReset.new(prior_turn_number: 5, prior_turn_state: @game.current_action["turn"]).apply!(@game)
    assert_equal 6, @game.turn_number
    refute @game.current_action.key?("turn")
  end

  test "unapply! restores prior_turn_number and prior_turn_state" do
    prior_turn_state = @game.current_action["turn"]
    c = Turn::Consequences::TurnReset.new(prior_turn_number: 5, prior_turn_state: prior_turn_state)
    c.apply!(@game)
    c.unapply!(@game)
    assert_equal 5, @game.turn_number
    assert_equal prior_turn_state, @game.current_action["turn"]
  end

  test "to_h round-trips through from_h" do
    c = Turn::Consequences::TurnReset.new(prior_turn_number: 5, prior_turn_state: { "x" => "y" })
    assert_equal "turn_reset", c.to_h["type"]
    assert_equal c, Turn::Consequences::TurnReset.from_h(c.to_h)
  end

  test "factory dispatches by type" do
    c = Turn::Consequences::TurnReset.new(prior_turn_number: 5, prior_turn_state: nil)
    assert_equal c, Turn::Consequences.from_h(c.to_h)
  end
end
