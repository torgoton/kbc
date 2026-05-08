require "test_helper"

class Turn::Consequences::OutpostActivatedTest < ActiveSupport::TestCase
  def setup
    @game = games(:game2player)
  end

  test "apply! sets current_action.turn.outpost_active to true" do
    @game.current_action = { "turn" => {} }
    Turn::Consequences::OutpostActivated.new(prior_active: false).apply!(@game)
    assert_equal true, @game.current_action.dig("turn", "outpost_active")
  end

  test "apply! creates the turn key when missing" do
    @game.current_action = nil
    Turn::Consequences::OutpostActivated.new(prior_active: false).apply!(@game)
    assert_equal true, @game.current_action.dig("turn", "outpost_active")
  end

  test "unapply! deletes the key when prior_active was false (clean round-trip)" do
    @game.current_action = { "turn" => {} }
    c = Turn::Consequences::OutpostActivated.new(prior_active: false)
    c.apply!(@game)
    c.unapply!(@game)
    refute @game.current_action.dig("turn").key?("outpost_active")
  end

  test "unapply! restores prior_active = true when it was previously active" do
    @game.current_action = { "turn" => { "outpost_active" => true } }
    c = Turn::Consequences::OutpostActivated.new(prior_active: true)
    c.apply!(@game)
    c.unapply!(@game)
    assert_equal true, @game.current_action.dig("turn", "outpost_active")
  end

  test "to_h round-trips through from_h" do
    c = Turn::Consequences::OutpostActivated.new(prior_active: false)
    assert_equal({ "type" => "outpost_activated", "prior_active" => false }, c.to_h)
    assert_equal c, Turn::Consequences::OutpostActivated.from_h(c.to_h)
  end

  test "factory dispatches by type" do
    c = Turn::Consequences::OutpostActivated.new(prior_active: false)
    assert_equal c, Turn::Consequences.from_h(c.to_h)
  end
end
