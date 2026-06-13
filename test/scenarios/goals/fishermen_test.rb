require "test_helper"

# Tracer for a Tier-1 (board-derived) goal: Fishermen is recomputed from the
# board via Scoring::Goals::Fishermen, not accumulated during play, so it can
# be exercised with direct settlement placement and read back through the
# Scoring seam.
class FishermenScenarioTest < ActiveSupport::TestCase
  test "a settlement adjacent to water scores a fishermen point" do
    scenario = GameScenario.new(goals: [ "fishermen" ])
    spot = scenario.empty_hex_adjacent_to("W", adjacent: true)
    raise "fixed board should offer a hex adjacent to water" unless spot

    scenario.place_settlement(0, at: spot)

    assert_equal 1, scenario.score_for("fishermen", 0)
  end

  test "a settlement with no adjacent water scores no fishermen point" do
    scenario = GameScenario.new(goals: [ "fishermen" ])
    spot = scenario.empty_hex_adjacent_to("W", adjacent: false)
    raise "fixed board should offer a hex with no adjacent water" unless spot

    scenario.place_settlement(0, at: spot)

    assert_equal 0, scenario.score_for("fishermen", 0)
  end
end
