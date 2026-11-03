require "test_helper"

# Native Soil: the decree's terrain is playable every turn, as if it were in the hand.
class NativeSoilScenarioTest < ActiveSupport::TestCase
  def native_soil_scenario(hand:, terrain:)
    GameScenario.new(hands: { 0 => hand }).tap do |scenario|
      scenario.game.update!(decree: { "name" => "native_soil", "terrain" => terrain })
    end
  end

  test "a player may build on the Native Soil terrain instead of their card, and it locks for the turn" do
    scenario = native_soil_scenario(hand: "G", terrain: "T")
    spots = scenario.buildable_cells
    assert spots.any? { |spot| scenario.terrain_at(spot) == "G" }
    native = spots.find { |spot| scenario.terrain_at(spot) == "T" }
    assert native, "timberland should be offered"

    scenario.build_settlement(at: native)

    assert_equal 0, scenario.owner_at(native)
    assert scenario.buildable_cells.all? { |spot| scenario.terrain_at(spot) == "T" }
  end

  test "the hand card still works, and the Native Soil card is not discarded at end of turn" do
    scenario = native_soil_scenario(hand: "G", terrain: "T")
    scenario.build_settlement(at: scenario.buildable_cells.find { |spot| scenario.terrain_at(spot) == "G" })
    scenario.build_settlement(at: scenario.buildable_cells.find { |spot| scenario.terrain_at(spot) == "G" })
    scenario.build_settlement(at: scenario.buildable_cells.find { |spot| scenario.terrain_at(spot) == "G" })
    scenario.end_turn

    assert_not_includes scenario.game.discard, "T"
    assert_includes scenario.game.game_players.map(&:hand_terrains).flatten, "T"
  end
end
