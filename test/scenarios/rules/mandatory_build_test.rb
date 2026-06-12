require "test_helper"

class MandatoryBuildScenarioTest < ActiveSupport::TestCase
  test "building on the hand terrain places a settlement, spends supply, and counts toward the mandatory three" do
    scenario = GameScenario.new(hands: { 0 => "G", 1 => "D" })
    spot = scenario.empty_hexes("G", 1).first

    scenario.build_settlement(at: spot)

    assert_equal 0, scenario.owner_at(spot)
    assert_equal 39, scenario.settlements_remaining(0)
    assert_equal 2, scenario.mandatory_remaining
  end

  test "building on terrain not matching the hand card is rejected" do
    scenario = GameScenario.new(hands: { 0 => "G", 1 => "D" })
    desert_spot = scenario.empty_hexes("D", 1).first

    assert_raises(GameScenario::IllegalMove) do
      scenario.build_settlement(at: desert_spot)
    end
    assert_nil scenario.owner_at(desert_spot)
    assert_equal 40, scenario.settlements_remaining(0)
  end
end
