require "test_helper"

class Turn::Consequences::SubPhasePoppedTest < ActiveSupport::TestCase
  def setup
    @game = games(:game2player)
    @prior = { "type" => "tile_build",
               "state" => { "restricted_terrain" => "G", "tile_klass" => "FarmTile", "tile_source" => "[2, 3]" } }
  end

  test "clears current_action.turn.sub_phase" do
    @game.current_action = { "turn" => { "sub_phase" => @prior } }
    Turn::Consequences::SubPhasePopped.new(prior_state: @prior).apply!(@game)
    assert_nil @game.current_action.dig("turn", "sub_phase")
  end

  test "no-op if no current_action" do
    @game.current_action = nil
    assert_nothing_raised { Turn::Consequences::SubPhasePopped.new(prior_state: @prior).apply!(@game) }
  end

  test "no-op if no turn key" do
    @game.current_action = { "type" => "mandatory" }
    assert_nothing_raised { Turn::Consequences::SubPhasePopped.new(prior_state: @prior).apply!(@game) }
    assert_equal "mandatory", @game.current_action["type"]
  end

  test "unapply! restores the prior sub_phase" do
    @game.current_action = { "turn" => { "sub_phase" => @prior } }
    c = Turn::Consequences::SubPhasePopped.new(prior_state: @prior)
    c.apply!(@game)
    c.unapply!(@game)
    assert_equal @prior, @game.current_action.dig("turn", "sub_phase")
  end

  test "equality is by value" do
    a = Turn::Consequences::SubPhasePopped.new(prior_state: @prior)
    b = Turn::Consequences::SubPhasePopped.new(prior_state: @prior)
    assert_equal a, b
  end
end
