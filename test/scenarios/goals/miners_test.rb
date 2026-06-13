require "test_helper"

# Tracer for a Tier-1 (board-derived) goal: Miners is recomputed from the
# board via Scoring::Goals::Miners, not accumulated during play, so it can be
# exercised with direct settlement placement and read back through the
# Scoring seam.
class MinersScenarioTest < ActiveSupport::TestCase
  test "a settlement adjacent to a mountain scores a miners point" do
    scenario = GameScenario.new(goals: [ "miners" ])
    spot = scenario.empty_hex_adjacent_to("M", adjacent: true)
    raise "fixed board should offer a hex adjacent to a mountain" unless spot

    scenario.place_settlement(0, at: spot)

    assert_equal 1, scenario.score_for("miners", 0)
  end

  test "a settlement with no adjacent mountain scores no miners point" do
    scenario = GameScenario.new(goals: [ "miners" ])
    spot = scenario.empty_hex_adjacent_to("M", adjacent: false)
    raise "fixed board should offer a hex with no adjacent mountain" unless spot

    scenario.place_settlement(0, at: spot)

    assert_equal 0, scenario.score_for("miners", 0)
  end
end
