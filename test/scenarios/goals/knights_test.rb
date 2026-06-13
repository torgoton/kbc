require "test_helper"

# Tracer for a Tier-1 (board-derived) goal: Knights is recomputed from the
# board via Scoring::Goals::Knights, not accumulated during play, so it can
# be exercised with direct settlement placement and read back through the
# Scoring seam.
class KnightsScenarioTest < ActiveSupport::TestCase
  test "settlements concentrated on one row score 2 points per settlement on that row" do
    scenario = GameScenario.new(goals: [ "knights" ])
    row_group = scenario.empty_buildable_hexes.group_by(&:first).values.find { |g| g.size >= 3 }
    raise "fixed board should offer a row with three empty hexes" unless row_group
    row_group.first(3).each { |spot| scenario.place_settlement(0, at: spot) }

    assert_equal 6, scenario.score_for("knights", 0)
  end

  test "settlements spread across rows score 2 points per settlement on the busiest row" do
    scenario = GameScenario.new(goals: [ "knights" ])
    groups = scenario.empty_buildable_hexes.group_by(&:first).values
    three_row = groups.find { |g| g.size >= 3 }
    raise "fixed board should offer a row with three empty hexes" unless three_row
    two_row = groups.find { |g| g.size >= 2 && g.first.first != three_row.first.first }
    raise "fixed board should offer a second row with two empty hexes" unless two_row

    three_row.first(3).each { |spot| scenario.place_settlement(0, at: spot) }
    two_row.first(2).each { |spot| scenario.place_settlement(0, at: spot) }

    assert_equal 6, scenario.score_for("knights", 0)
  end
end
