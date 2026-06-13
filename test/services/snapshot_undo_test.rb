require "test_helper"

class SnapshotUndoTest < ActiveSupport::TestCase
  test "capture_snapshot includes bonus_scores, end_trigger_count, and move_count" do
    scenario = GameScenario.new(hands: { 0 => "G", 1 => "D" })
    snap = scenario.game.capture_snapshot

    assert snap.key?("end_trigger_count"), "snapshot must carry end_trigger_count"
    assert snap.key?("move_count"), "snapshot must carry move_count"
    assert snap["players"].first.key?("bonus_scores"), "each player must carry bonus_scores"
  end

  test "restore_snapshot! reverts a build: board cleared, supply and move_count restored" do
    scenario = GameScenario.new(hands: { 0 => "G", 1 => "D" })
    snap = scenario.game.capture_snapshot
    supply_before = scenario.settlements_remaining(0)

    spot = scenario.empty_hexes("G", 1).first
    scenario.build_settlement(at: spot)
    assert_equal 0, scenario.owner_at(spot), "settlement should be built before restore"

    scenario.game.restore_snapshot!(snap)

    assert_nil scenario.owner_at(spot), "settlement should be gone after restore"
    assert_equal supply_before, scenario.settlements_remaining(0)
    assert_equal snap["move_count"], scenario.game.move_count
  end
end
