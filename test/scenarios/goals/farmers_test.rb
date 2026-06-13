require "test_helper"

# Tracer for a Tier-1 (board-derived) goal: Farmers is recomputed from the
# board via Scoring::Goals::Farmers, not accumulated during play, so it can
# be exercised with direct settlement placement and read back through the
# Scoring seam.
class FarmersScenarioTest < ActiveSupport::TestCase
  test "settlements confined to one board section score no farmers points" do
    scenario = GameScenario.new(goals: [ "farmers" ])
    spots = quadrant_hexes(scenario)[0].first(2)
    raise "fixed board should offer two empty hexes in one section" unless spots.size == 2

    spots.each { |spot| scenario.place_settlement(0, at: spot) }

    assert_equal 0, scenario.score_for("farmers", 0)
  end

  test "settlements spread across all 4 sections score 3 per settlement in the smallest section" do
    scenario = GameScenario.new(goals: [ "farmers" ])
    quadrants = quadrant_hexes(scenario)
    spots = quadrants[0].first(2) + quadrants[1].first(1) + quadrants[2].first(1) + quadrants[3].first(1)
    raise "fixed board should offer empty hexes in all 4 sections" unless spots.size == 5

    spots.each { |spot| scenario.place_settlement(0, at: spot) }

    assert_equal 3, scenario.score_for("farmers", 0)
  end

  private

  # Empty, buildable hexes grouped by board section (0-3), matching
  # Scoring::Goals::Farmers#quadrant_counts.
  def quadrant_hexes(scenario)
    scenario.empty_buildable_hexes.group_by { |row, col| (row / 10) * 2 + (col / 10) }
  end
end
