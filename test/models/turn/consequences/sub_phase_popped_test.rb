require "test_helper"

class Turn::Consequences::SubPhasePoppedTest < ActiveSupport::TestCase
  def setup
    @game = games(:game2player)
  end

  test "clears current_action.turn.sub_phase" do
    @game.current_action = { "turn" => { "sub_phase" => { "type" => "tile_build", "state" => {} } } }
    Turn::Consequences::SubPhasePopped.new.apply!(@game)
    assert_nil @game.current_action.dig("turn", "sub_phase")
  end

  test "no-op if no current_action" do
    @game.current_action = nil
    assert_nothing_raised { Turn::Consequences::SubPhasePopped.new.apply!(@game) }
  end

  test "no-op if no turn key" do
    @game.current_action = { "type" => "mandatory" }
    assert_nothing_raised { Turn::Consequences::SubPhasePopped.new.apply!(@game) }
    assert_equal "mandatory", @game.current_action["type"]
  end

  test "two instances are equal" do
    assert_equal Turn::Consequences::SubPhasePopped.new, Turn::Consequences::SubPhasePopped.new
  end
end
