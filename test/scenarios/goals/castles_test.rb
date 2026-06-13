require "test_helper"

# Tracer for a Tier-1 (board-derived) goal: Castles is recomputed from the
# board via Scoring::Goals::Castles, not accumulated during play, so it can
# be exercised with direct settlement placement and read back through the
# Scoring seam.
class CastlesScenarioTest < ActiveSupport::TestCase
  test "a settlement adjacent to a castle scores 3 castles points" do
    scenario = GameScenario.new(goals: [ "castles" ])
    spot = scenario.empty_hex_adjacent_to("S", adjacent: true)
    raise "fixed board should offer a hex adjacent to a castle" unless spot

    scenario.place_settlement(0, at: spot)

    assert_equal 3, scenario.score_for("castles", 0)
  end

  test "a settlement with no adjacent castle scores no castles points" do
    scenario = GameScenario.new(goals: [ "castles" ])
    spot = scenario.empty_hex_adjacent_to("S", adjacent: false)
    raise "fixed board should offer a hex with no adjacent castle" unless spot

    scenario.place_settlement(0, at: spot)

    assert_equal 0, scenario.score_for("castles", 0)
  end

  test "2 settlements next to the same castle score 3 castles points total" do
    scenario = GameScenario.new(goals: [ "castles" ])
    spots = scenario.empty_hexes_adjacent_to("S", 2)
    raise "fixed board should offer a castle with two empty neighbors" unless spots

    spots.each { |spot| scenario.place_settlement(0, at: spot) }

    assert_equal 3, scenario.score_for("castles", 0)
  end
end
