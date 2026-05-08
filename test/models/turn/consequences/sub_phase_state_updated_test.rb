require "test_helper"

class Turn::Consequences::SubPhaseStateUpdatedTest < ActiveSupport::TestCase
  def setup
    @game = games(:game2player)
    @prior = { "fort_terrain" => "G", "builds_remaining" => 2 }
    @new   = { "fort_terrain" => "G", "builds_remaining" => 1 }
    @game.current_action = { "turn" => { "sub_phase" => { "type" => "fort", "state" => @prior } } }
  end

  test "apply! replaces the sub_phase state with new_state" do
    Turn::Consequences::SubPhaseStateUpdated.new(prior_state: @prior, new_state: @new).apply!(@game)
    assert_equal @new, @game.current_action.dig("turn", "sub_phase", "state")
  end

  test "unapply! restores prior_state" do
    c = Turn::Consequences::SubPhaseStateUpdated.new(prior_state: @prior, new_state: @new)
    c.apply!(@game)
    c.unapply!(@game)
    assert_equal @prior, @game.current_action.dig("turn", "sub_phase", "state")
  end

  test "to_h round-trips through from_h" do
    c = Turn::Consequences::SubPhaseStateUpdated.new(prior_state: @prior, new_state: @new)
    h = c.to_h
    assert_equal "sub_phase_state_updated", h["type"]
    assert_equal @prior, h["prior_state"]
    assert_equal @new, h["new_state"]
    assert_equal c, Turn::Consequences::SubPhaseStateUpdated.from_h(h)
  end

  test "factory dispatches by type" do
    c = Turn::Consequences::SubPhaseStateUpdated.new(prior_state: @prior, new_state: @new)
    assert_equal c, Turn::Consequences.from_h(c.to_h)
  end
end
