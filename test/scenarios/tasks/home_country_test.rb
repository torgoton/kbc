require "test_helper"

# Tracer for a Tier-1 (board-derived) task: HomeCountry is recomputed from
# the board via Scoring::Tasks::HomeCountry, not accumulated during play, so
# it can be exercised with direct settlement placement and read back through
# the Scoring seam.
class HomeCountryScenarioTest < ActiveSupport::TestCase
  # [10, 13] and [10, 14] form a complete, isolated 2-hex mountain area on
  # the fixed board.
  MOUNTAIN_AREA = [ [ 10, 13 ], [ 10, 14 ] ].freeze

  # [15, 4] is a complete, isolated 1-hex water area on the fixed board.
  WATER_AREA = [ [ 15, 4 ] ].freeze

  test "controlling every hex of a terrain area scores 5 home_country points" do
    scenario = GameScenario.new(tasks: [ "home_country" ])
    MOUNTAIN_AREA.each { |spot| scenario.place_settlement(0, at: spot) }

    assert_equal 5, scenario.score_for("home_country", 0)
  end

  test "controlling 2 complete terrain areas still scores 5 home_country points" do
    scenario = GameScenario.new(tasks: [ "home_country" ])
    (MOUNTAIN_AREA + WATER_AREA).each { |spot| scenario.place_settlement(0, at: spot) }

    assert_equal 5, scenario.score_for("home_country", 0)
  end

  test "controlling only part of a terrain area scores no home_country points" do
    scenario = GameScenario.new(tasks: [ "home_country" ])
    scenario.place_settlement(0, at: MOUNTAIN_AREA.first)

    assert_equal 0, scenario.score_for("home_country", 0)
  end
end
