require "test_helper"

# Tracer for a Tier-2 (callback-derived) goal. Ambassadors is scored inside the
# turn engine as builds happen, not recomputed from the board, so it must be
# driven end-to-end through a real build action and read back through the
# Scoring seam. (Hand-setting bonus_scores would prove nothing.) The Tier-1
# board-derived seam is covered by goals/hermits_test.rb.
class AmbassadorsScenarioTest < ActiveSupport::TestCase
  test "building adjacent to an opponent settlement scores an ambassadors point" do
    scenario = GameScenario.new(goals: [ "ambassadors" ], hands: { 0 => "G", 1 => "D" })
    build_spot = scenario.empty_hexes("G", 1).first
    opponent_hex = scenario.neighbors(build_spot).find { |n| scenario.owner_at(n).nil? }
    scenario.place_settlement(1, at: opponent_hex)

    assert_equal 0, scenario.score_for("ambassadors", 0)
    scenario.build_settlement(at: build_spot)
    assert_equal 1, scenario.score_for("ambassadors", 0)
  end

  test "building away from any opponent scores no ambassadors point" do
    scenario = GameScenario.new(goals: [ "ambassadors" ], hands: { 0 => "G", 1 => "D" })
    build_spot = scenario.empty_hexes("G", 1).first

    scenario.build_settlement(at: build_spot)

    assert_equal 0, scenario.score_for("ambassadors", 0)
  end
end
