require "test_helper"

class LegalBuildsScenarioTest < ActiveSupport::TestCase
  test "with no settlements on the board, every empty hex of the hand terrain is legal" do
    scenario = GameScenario.new(hands: { 0 => "G", 1 => "D" })
    all_grass = scenario.empty_hexes("G", 400)

    assert_equal all_grass.sort, scenario.legal_builds(0).sort
  end

  test "builds are restricted to adjacent hand-terrain hexes if any exist" do
    scenario = GameScenario.new(hands: { 0 => "G", 1 => "D" })
    home = scenario.empty_hexes("G", 50).find do |spot|
      scenario.neighbors(spot).any? { |n| scenario.terrain_at(n) == "G" }
    end
    raise "fixed board should contain adjacent grass hexes" unless home
    scenario.place_settlement(0, at: home)

    expected = scenario.neighbors(home).select do |n|
      scenario.terrain_at(n) == "G" && scenario.owner_at(n).nil?
    end

    assert_equal expected.sort, scenario.legal_builds(0).sort
  end
end
