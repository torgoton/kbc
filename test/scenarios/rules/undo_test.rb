require "test_helper"

class UndoScenarioTest < ActiveSupport::TestCase
  test "undo after a build removes the settlement and restores supply and mandatory count" do
    scenario = GameScenario.new(hands: { 0 => "G", 1 => "D" })
    spot = scenario.empty_hexes("G", 1).first
    scenario.build_settlement(at: spot)

    scenario.undo

    assert_nil scenario.owner_at(spot)
    assert_equal 40, scenario.settlements_remaining(0)
    assert_equal 3, scenario.mandatory_remaining
  end
end
