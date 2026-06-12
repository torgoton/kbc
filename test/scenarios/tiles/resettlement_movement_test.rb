require "test_helper"

class ResettlementMovementScenarioTest < ActiveSupport::TestCase
  # Tracer for the stepped-movement contract: a settlement mover relocates one
  # hex per call, vacating its source. (The full "steps up to allowance / picks
  # up en route / forfeits" contract is parameterized across movers in Phase 3.)
  test "resettlement relocates a settlement one hex per step, vacating the source" do
    scenario = GameScenario.new(hands: { 0 => "G", 1 => "D" })
    scenario.give_tile(0, "ResettlementTile", from: [ 0, 0 ])
    start = scenario.empty_hexes("G", 1).first
    scenario.place_settlement(0, at: start)
    step = scenario.neighbors(start).find do |n|
      scenario.terrain_at(n) == "G" && scenario.owner_at(n).nil?
    end
    raise "fixed board should offer an adjacent grass hex" unless step

    scenario.activate_tile(:resettlement)
    scenario.select_settlement(at: start)
    scenario.move_step(to: step)

    assert_equal 0, scenario.owner_at(step)
    assert_nil scenario.owner_at(start)
  end
end
