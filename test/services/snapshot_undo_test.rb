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

  test "TurnEngine.new does not raise for a waiting game with no current player" do
    game = games(:waiting_game)
    assert_nil game.current_player

    assert_nothing_raised { TurnEngine.new(game) }
  end

  test "capture_snapshot's current_action is independent of the live game's current_action" do
    scenario = GameScenario.new(hands: { 0 => "G", 1 => "D" })
    scenario.game.update!(current_action: { "type" => "mandatory", "builds" => [ "0,0" ] })

    snap = scenario.game.capture_snapshot
    scenario.game.current_action["builds"] << "1,1"

    assert_equal [ "0,0" ], snap["current_action"]["builds"]
  end

  test "a deliberate build move carries the pre-click snapshot; consequential moves do not" do
    scenario = GameScenario.new(hands: { 0 => "G", 1 => "D" })
    spot = scenario.empty_hexes("G", 1).first
    scenario.build_settlement(at: spot)

    deliberate = scenario.game.moves.where(deliberate: true).order(:id).last
    assert_not_nil deliberate.snapshot_before, "deliberate move must carry snapshot_before"

    consequential = scenario.game.moves.where(deliberate: false).order(:id).last
    assert_nil consequential&.snapshot_before, "consequential moves must not carry a snapshot"
  end
end
