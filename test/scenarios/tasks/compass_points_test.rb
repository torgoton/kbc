require "test_helper"

# Tracer for a Tier-1 (board-derived) task: CompassPoints is recomputed from
# the board via Scoring::Tasks::CompassPoints, not accumulated during play,
# so it can be exercised with direct settlement placement and read back
# through the Scoring seam.
class CompassPointsScenarioTest < ActiveSupport::TestCase
  test "a settlement on every edge of the board scores 10 compass_points points" do
    scenario = GameScenario.new(tasks: [ "compass_points" ])
    [ [ 0, 5 ], [ 19, 5 ], [ 5, 0 ], [ 5, 19 ] ].each { |spot| scenario.place_settlement(0, at: spot) }

    assert_equal 10, scenario.score_for("compass_points", 0)
  end

  test "missing one edge of the board scores no compass_points points" do
    scenario = GameScenario.new(tasks: [ "compass_points" ])
    [ [ 0, 5 ], [ 19, 5 ], [ 5, 0 ] ].each { |spot| scenario.place_settlement(0, at: spot) }

    assert_equal 0, scenario.score_for("compass_points", 0)
  end
end
