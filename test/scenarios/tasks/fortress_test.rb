require "test_helper"

# Tracer for a Tier-1 (board-derived) task: Fortress is recomputed from the
# board via Scoring::Tasks::Fortress, not accumulated during play, so it can
# be exercised with direct settlement placement and read back through the
# Scoring seam.
class FortressScenarioTest < ActiveSupport::TestCase
  CENTER = [ 10, 10 ].freeze
  RING = [ [ 10, 9 ], [ 10, 11 ], [ 9, 9 ], [ 9, 10 ], [ 11, 9 ], [ 11, 10 ] ].freeze

  CENTER2 = [ 4, 4 ].freeze
  RING2 = [ [ 4, 3 ], [ 4, 5 ], [ 3, 3 ], [ 3, 4 ], [ 5, 3 ], [ 5, 4 ] ].freeze

  test "a settlement surrounded by 6 settlements scores 6 fortress points" do
    scenario = GameScenario.new(tasks: [ "fortress" ])
    scenario.place_settlement(0, at: CENTER)
    RING.each { |spot| scenario.place_settlement(0, at: spot) }

    assert_equal 6, scenario.score_for("fortress", 0)
  end

  test "two settlements each surrounded by 6 settlements still scores 6 fortress points" do
    scenario = GameScenario.new(tasks: [ "fortress" ])
    scenario.place_settlement(0, at: CENTER)
    RING.each { |spot| scenario.place_settlement(0, at: spot) }
    scenario.place_settlement(0, at: CENTER2)
    RING2.each { |spot| scenario.place_settlement(0, at: spot) }

    assert_equal 6, scenario.score_for("fortress", 0)
  end

  test "a settlement surrounded by only 5 settlements scores no fortress points" do
    scenario = GameScenario.new(tasks: [ "fortress" ])
    scenario.place_settlement(0, at: CENTER)
    RING[0..4].each { |spot| scenario.place_settlement(0, at: spot) }

    assert_equal 0, scenario.score_for("fortress", 0)
  end
end
