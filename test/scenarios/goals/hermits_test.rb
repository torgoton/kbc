require "test_helper"

class HermitsScenarioTest < ActiveSupport::TestCase
  test "hermits awards one point per separate settlement area" do
    scenario = GameScenario.new(goals: [ "hermits" ], hands: { 0 => "G", 1 => "D" })
    first = scenario.empty_hexes("G", 1).first
    apart = scenario.empty_hexes("G", 50).find do |spot|
      spot != first && !scenario.neighbors(first).include?(spot)
    end
    scenario.place_settlement(0, at: first)
    scenario.place_settlement(0, at: apart)

    assert_equal 2, scenario.score_for("hermits", 0)
    assert_equal 0, scenario.score_for("hermits", 1)
  end
end
