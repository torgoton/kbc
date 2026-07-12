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

  test "with a two-card hand, both terrains are buildable before the first build" do
    scenario = GameScenario.new(hands: { 0 => %w[G D] })

    terrains = scenario.buildable_cells.map { |cell| scenario.terrain_at(cell) }.uniq

    assert_includes terrains, "G"
    assert_includes terrains, "D"
  end

  test "the first build locks a two-card hand to that terrain for the rest of the turn" do
    scenario = GameScenario.new(hands: { 0 => %w[G D] })

    scenario.build_settlement(at: scenario.empty_hexes("G", 1).first)

    scenario.buildable_cells.each { |cell| assert_equal "G", scenario.terrain_at(cell) }
    assert_raises(GameScenario::IllegalMove) do
      scenario.build_settlement(at: scenario.empty_hexes("D", 1).first)
    end
  end
end
