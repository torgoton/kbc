require "test_helper"

class SnapshotUndoTest < ActiveSupport::TestCase
  test "capture_snapshot includes bonus_scores, end_trigger_count, and move_count" do
    scenario = GameScenario.new(hands: { 0 => "G", 1 => "D" })
    snap = scenario.game.capture_snapshot

    assert snap.key?("end_trigger_count"), "snapshot must carry end_trigger_count"
    assert snap.key?("move_count"), "snapshot must carry move_count"
    assert snap["players"].first.key?("bonus_scores"), "each player must carry bonus_scores"
  end
end
