require "test_helper"

class TurnPhaseClickTest < ActiveSupport::TestCase
  # Records outgoing engine messages so a phase's click can be tested in
  # isolation, without a Game. Asserts the command the phase SENDS, per the
  # State-pattern design (behavior itself is pinned by test/scenarios).
  class RecordingEngine
    attr_reader :sent
    def initialize = @sent = []
    def method_missing(name, *args) = @sent << [ name, *args ]
    def respond_to_missing?(*) = true
  end

  def coord(row, col) = Coordinate.new(row, col)

  test "MandatoryBuildPhase#click tells the engine to build_settlement" do
    engine = RecordingEngine.new
    TurnPhase::MandatoryBuildPhase.new.click(coord(3, 6), engine)
    assert_equal [ [ :build_settlement, 3, 6 ] ], engine.sent
  end

  test "SettlementMovePhase#click selects the source when no from is set" do
    engine = RecordingEngine.new
    phase = TurnPhase::SettlementMovePhase.new(action_type: "paddock", klass_name: "PaddockTile")
    phase.click(coord(4, 5), engine)
    assert_equal [ [ :select_settlement, 4, 5 ] ], engine.sent
  end

  test "SettlementMovePhase#click moves to the destination once from is set" do
    engine = RecordingEngine.new
    phase = TurnPhase::SettlementMovePhase.new(action_type: "paddock", klass_name: "PaddockTile", from: "[4, 5]")
    phase.click(coord(6, 7), engine)
    assert_equal [ [ :move_settlement, 6, 7 ] ], engine.sent
  end

  test "ResettlementPhase#click selects the source when no from is set" do
    engine = RecordingEngine.new
    phase = TurnPhase::ResettlementPhase.new(budget: 5, moves: 0)
    phase.click(coord(4, 5), engine)
    assert_equal [ [ :select_settlement, 4, 5 ] ], engine.sent
  end

  test "ResettlementPhase#click moves to the destination once from is set" do
    engine = RecordingEngine.new
    phase = TurnPhase::ResettlementPhase.new(budget: 5, moves: 0, from: "[4, 5]")
    phase.click(coord(6, 7), engine)
    assert_equal [ [ :move_settlement, 6, 7 ] ], engine.sent
  end
end
