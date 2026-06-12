require "test_helper"

# Tracer for the undo round-trip mode: assert_undo_round_trip runs an action,
# undoes it, asserts the exact pre-action state is restored, then replays the
# action and asserts the post-action state is reproduced. This is the mechanism
# that lets the scenario suite prove undo preserves state across the refactor.
class UndoRoundTripScenarioTest < ActiveSupport::TestCase
  test "a mandatory build round-trips through undo" do
    scenario = GameScenario.new(hands: { 0 => "G", 1 => "D" })
    spot = scenario.empty_hexes("G", 1).first

    assert_undo_round_trip(scenario) { scenario.build_settlement(at: spot) }
  end

  test "a resettlement step round-trips through undo" do
    scenario = GameScenario.new(hands: { 0 => "G", 1 => "D" })
    scenario.give_tile(0, "ResettlementTile", from: [ 0, 0 ])
    start = scenario.empty_hexes("G", 1).first
    scenario.place_settlement(0, at: start)
    step = scenario.neighbors(start).find do |n|
      scenario.terrain_at(n) == "G" && scenario.owner_at(n).nil?
    end
    scenario.activate_tile(:resettlement)
    scenario.select_settlement(at: start)

    assert_undo_round_trip(scenario) { scenario.move_step(to: step) }
  end
end
