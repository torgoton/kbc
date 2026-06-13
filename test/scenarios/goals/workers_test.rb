require "test_helper"

# Tracer for a Tier-1 (board-derived) goal: Workers is recomputed from the
# board via Scoring::Goals::Workers, not accumulated during play, so it can
# be exercised with direct settlement placement and read back through the
# Scoring seam.
class WorkersScenarioTest < ActiveSupport::TestCase
  test "a settlement adjacent to a castle or location hex scores a workers point" do
    scenario = GameScenario.new(goals: [ "workers" ])
    spot = scenario.empty_hex_adjacent_to(%w[S L], adjacent: true)
    raise "fixed board should offer a hex adjacent to a castle or location" unless spot

    scenario.place_settlement(0, at: spot)

    assert_equal 1, scenario.score_for("workers", 0)
  end

  test "a settlement with no adjacent castle or location hex scores no workers point" do
    scenario = GameScenario.new(goals: [ "workers" ])
    spot = scenario.empty_hex_adjacent_to(%w[S L], adjacent: false)
    raise "fixed board should offer a hex with no adjacent castle or location" unless spot

    scenario.place_settlement(0, at: spot)

    assert_equal 0, scenario.score_for("workers", 0)
  end
end
