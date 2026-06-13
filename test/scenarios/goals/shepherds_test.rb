require "test_helper"

# Tracer for a Tier-2 (callback-derived) goal: Shepherds is scored inside the
# turn engine at build time, not recomputed from the board, so it must be
# driven end-to-end through a real build action and read back through the
# Scoring seam. Mirrors goals/ambassadors_test.rb.
class ShepherdsScenarioTest < ActiveSupport::TestCase
  test "building with no adjacent empty same-terrain hex scores a shepherds point" do
    scenario = GameScenario.new(goals: [ "shepherds" ], hands: { 0 => "G", 1 => "D" })
    build_spot = scenario.empty_hexes("G", 1).first
    scenario.neighbors(build_spot).each do |n|
      scenario.place_settlement(1, at: n) if scenario.terrain_at(n) == "G"
    end

    assert_equal 0, scenario.score_for("shepherds", 0)
    scenario.build_settlement(at: build_spot)
    assert_equal 2, scenario.score_for("shepherds", 0)
  end

  test "building next to an empty same-terrain hex scores no shepherds point" do
    scenario = GameScenario.new(goals: [ "shepherds" ], hands: { 0 => "G", 1 => "D" })
    build_spot = scenario.empty_hexes("G", 1).first
    raise "fixed board should offer a grass hex with an empty grass neighbor" unless
      scenario.neighbors(build_spot).any? { |n| scenario.terrain_at(n) == "G" && scenario.owner_at(n).nil? }

    scenario.build_settlement(at: build_spot)

    assert_equal 0, scenario.score_for("shepherds", 0)
  end
end
