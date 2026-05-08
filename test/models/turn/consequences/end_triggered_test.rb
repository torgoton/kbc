require "test_helper"

class Turn::Consequences::EndTriggeredTest < ActiveSupport::TestCase
  def setup
    @game = games(:game2player)
    @game.end_trigger_count = 0
  end

  test "apply! increments game.end_trigger_count" do
    Turn::Consequences::EndTriggered.new(player: 0).apply!(@game)
    assert_equal 1, @game.end_trigger_count
  end

  test "apply! adds to an existing trigger count" do
    @game.end_trigger_count = 1
    Turn::Consequences::EndTriggered.new(player: 0).apply!(@game)
    assert_equal 2, @game.end_trigger_count
  end

  test "unapply! decrements game.end_trigger_count" do
    @game.end_trigger_count = 2
    c = Turn::Consequences::EndTriggered.new(player: 0)
    c.apply!(@game)
    c.unapply!(@game)
    assert_equal 2, @game.end_trigger_count
  end

  test "to_h round-trips through from_h" do
    c = Turn::Consequences::EndTriggered.new(player: 0)
    assert_equal({ "type" => "end_triggered", "player" => 0 }, c.to_h)
    assert_equal c, Turn::Consequences::EndTriggered.from_h(c.to_h)
  end

  test "factory dispatches by type" do
    c = Turn::Consequences::EndTriggered.new(player: 0)
    assert_equal c, Turn::Consequences.from_h(c.to_h)
  end
end
