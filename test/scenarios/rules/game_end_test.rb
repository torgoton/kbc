require "test_helper"

# The end of the game is triggered when a player builds their last settlement
# from supply; the game then ends once the last player in turn order finishes a
# turn while the trigger is set. A settlement returned to a triggered player
# (e.g. by an opponent's Sword) does not undo the trigger.
class GameEndScenarioTest < ActiveSupport::TestCase
  test "building the last settlement from supply triggers the end of the game" do
    scenario = GameScenario.new(hands: { 0 => "G", 1 => "D" })
    scenario.set_settlements(0, 1)

    scenario.build_settlement(at: scenario.empty_hexes("G", 1).first)

    assert_equal 1, scenario.end_trigger_count
  end

  test "building a settlement while supply remains does not trigger the end" do
    scenario = GameScenario.new(hands: { 0 => "G", 1 => "D" })

    scenario.build_settlement(at: scenario.empty_hexes("G", 1).first)

    assert_equal 0, scenario.end_trigger_count
  end

  test "the game ends when the last player finishes a turn after the end is triggered" do
    scenario = GameScenario.new(hands: { 0 => "G", 1 => "D" })
    scenario.make_current(1)      # order 1 is the last of two players
    scenario.set_settlements(1, 1)
    scenario.set_mandatory(1)     # a single build completes this turn

    scenario.build_settlement(at: scenario.empty_hexes("D", 1).first)
    assert_equal 1, scenario.end_trigger_count

    scenario.end_turn

    assert_equal "completed", scenario.state
  end

  test "the game keeps playing when a non-last player finishes a turn after the trigger" do
    scenario = GameScenario.new(hands: { 0 => "G", 1 => "D" })
    scenario.set_settlements(0, 1) # order 0 is not the last player
    scenario.set_mandatory(1)

    scenario.build_settlement(at: scenario.empty_hexes("G", 1).first)
    scenario.end_turn

    assert_equal "playing", scenario.state
  end

  test "undoing the triggering build round-trips the end trigger back off" do
    scenario = GameScenario.new(hands: { 0 => "G", 1 => "D" })
    scenario.set_settlements(0, 1)

    assert_undo_round_trip(scenario) do
      scenario.build_settlement(at: scenario.empty_hexes("G", 1).first)
    end
  end

  test "a Sword returning a settlement to a triggered player does not clear the trigger" do
    scenario = GameScenario.new(hands: { 0 => "G", 1 => "D" })
    scenario.set_settlements(0, 1)
    scenario.set_mandatory(1)
    last_settlement = scenario.empty_hexes("G", 1).first

    scenario.build_settlement(at: last_settlement) # player 0 spends their last settlement
    assert_equal 1, scenario.end_trigger_count
    scenario.end_turn                              # play passes to player 1

    scenario.give_tile(1, "SwordTile", from: [ 0, 0 ])
    scenario.activate_tile(:sword)
    scenario.remove_settlement(at: last_settlement) # returns the settlement to player 0's supply

    assert_equal 1, scenario.settlements_remaining(0)
    assert_equal 1, scenario.end_trigger_count
  end
end
