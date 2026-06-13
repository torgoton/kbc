require "test_helper"

# Tracer for a Tier-1 (board-derived) goal: Discoverers is recomputed from
# the board via Scoring::Goals::Discoverers, not accumulated during play, so
# it can be exercised with direct settlement placement and read back through
# the Scoring seam.
class DiscoverersScenarioTest < ActiveSupport::TestCase
  test "settlements on distinct rows each score a discoverers point" do
    scenario = GameScenario.new(goals: [ "discoverers" ])
    hexes = scenario.empty_buildable_hexes
    first = hexes.first
    second = hexes.find { |row, _| row != first.first }
    raise "fixed board should offer empty hexes on at least two rows" unless second

    scenario.place_settlement(0, at: first)
    scenario.place_settlement(0, at: second)

    assert_equal 2, scenario.score_for("discoverers", 0)
  end

  test "settlements on the same row score only one discoverers point" do
    scenario = GameScenario.new(goals: [ "discoverers" ])
    row_group = scenario.empty_buildable_hexes.group_by(&:first).values.find { |g| g.size >= 2 }
    raise "fixed board should offer a row with two empty hexes" unless row_group
    first, second = row_group.first(2)

    scenario.place_settlement(0, at: first)
    scenario.place_settlement(0, at: second)

    assert_equal 1, scenario.score_for("discoverers", 0)
  end
end
