require "test_helper"

# Tracer for a Tier-1 (board-derived) task: PlaceOfRefuge is recomputed from
# the board via Scoring::Tasks::PlaceOfRefuge, not accumulated during play,
# so it can be exercised with direct settlement placement and read back
# through the Scoring seam.
class PlaceOfRefugeScenarioTest < ActiveSupport::TestCase
  # [6, 11] is a location ("L") hex on the fixed board; its 6 neighbors.
  RING = [ [ 6, 10 ], [ 6, 12 ], [ 5, 10 ], [ 5, 11 ], [ 7, 10 ], [ 7, 11 ] ].freeze

  # [11, 7] is another location ("L") hex on the fixed board; its 6 neighbors.
  RING2 = [ [ 11, 6 ], [ 11, 8 ], [ 10, 7 ], [ 10, 8 ], [ 12, 7 ], [ 12, 8 ] ].freeze

  test "a special space surrounded by your settlements scores 8 place_of_refuge points" do
    scenario = GameScenario.new(tasks: [ "place_of_refuge" ])
    RING.each { |spot| scenario.place_settlement(0, at: spot) }

    assert_equal 8, scenario.score_for("place_of_refuge", 0)
  end

  test "surrounding 2 special spaces still scores 8 place_of_refuge points" do
    scenario = GameScenario.new(tasks: [ "place_of_refuge" ])
    (RING + RING2).each { |spot| scenario.place_settlement(0, at: spot) }

    assert_equal 8, scenario.score_for("place_of_refuge", 0)
  end

  test "a special space surrounded by only 5 of your settlements scores no place_of_refuge points" do
    scenario = GameScenario.new(tasks: [ "place_of_refuge" ])
    RING[0..4].each { |spot| scenario.place_settlement(0, at: spot) }

    assert_equal 0, scenario.score_for("place_of_refuge", 0)
  end
end
