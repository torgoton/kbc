require "test_helper"

# Tracer for a Tier-1 (board-derived) task: Road is recomputed from the
# board via Scoring::Tasks::Road, not accumulated during play, so it can be
# exercised with direct settlement placement and read back through the
# Scoring seam.
class RoadScenarioTest < ActiveSupport::TestCase
  # A continuous diagonal line of 7 hexes (constant cube q-coordinate).
  LINE = [ [ 0, 5 ], [ 1, 5 ], [ 2, 6 ], [ 3, 6 ], [ 4, 7 ], [ 5, 7 ], [ 6, 8 ] ].freeze

  # A second, separate continuous diagonal line of 7 hexes (constant cube
  # q-coordinate).
  LINE2 = [ [ 0, 10 ], [ 1, 10 ], [ 2, 11 ], [ 3, 11 ], [ 4, 12 ], [ 5, 12 ], [ 6, 13 ] ].freeze

  test "7 settlements in a continuous diagonal line scores 7 road points" do
    scenario = GameScenario.new(tasks: [ "road" ])
    LINE.each { |spot| scenario.place_settlement(0, at: spot) }

    assert_equal 7, scenario.score_for("road", 0)
  end

  test "2 separate diagonal lines of 7 still scores 7 road points" do
    scenario = GameScenario.new(tasks: [ "road" ])
    (LINE + LINE2).each { |spot| scenario.place_settlement(0, at: spot) }

    assert_equal 7, scenario.score_for("road", 0)
  end

  test "6 settlements in a continuous diagonal line scores no road points" do
    scenario = GameScenario.new(tasks: [ "road" ])
    LINE[0..5].each { |spot| scenario.place_settlement(0, at: spot) }

    assert_equal 0, scenario.score_for("road", 0)
  end
end
