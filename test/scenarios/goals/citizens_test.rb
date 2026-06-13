require "test_helper"

# Tracer for a Tier-1 (board-derived) goal: Citizens is recomputed from the
# board via Scoring::Goals::Citizens, not accumulated during play, so it can
# be exercised with direct settlement placement and read back through the
# Scoring seam.
class CitizensScenarioTest < ActiveSupport::TestCase
  test "a connected group of 4 settlements scores 2 citizens points" do
    scenario = GameScenario.new(goals: [ "citizens" ])
    chain = scenario.connected_empty_hexes(4)
    raise "fixed board should offer a chain of 4 connected empty hexes" unless chain

    chain.each { |spot| scenario.place_settlement(0, at: spot) }

    assert_equal 2, scenario.score_for("citizens", 0)
  end

  test "citizens score is based on the largest group, not the total" do
    scenario = GameScenario.new(goals: [ "citizens" ])
    large_group = scenario.connected_empty_hexes(5)
    raise "fixed board should offer a chain of 5 connected empty hexes" unless large_group

    excluded = (large_group + large_group.flat_map { |spot| scenario.neighbors(spot) }).uniq
    small_group = scenario.connected_empty_hexes(2, excluding: excluded)
    raise "fixed board should offer a separate chain of 2 connected empty hexes" unless small_group

    (large_group + small_group).each { |spot| scenario.place_settlement(0, at: spot) }

    assert_equal 2, scenario.score_for("citizens", 0)
  end
end
