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

  test "MeepleActionPhase#click tells the engine to execute_meeple_action" do
    engine = RecordingEngine.new
    phase = TurnPhase::MeepleActionPhase.new(action_type: "barracks", klass_name: "BarracksTile")
    phase.click(coord(2, 3), engine)
    assert_equal [ [ :execute_meeple_action, 2, 3 ] ], engine.sent
  end

  test "MeepleMovementPhase#click tells the engine to execute_meeple_action" do
    engine = RecordingEngine.new
    phase = TurnPhase::MeepleMovementPhase.new(action_type: "wagon", klass_name: "WagonTile")
    phase.click(coord(2, 3), engine)
    assert_equal [ [ :execute_meeple_action, 2, 3 ] ], engine.sent
  end

  test "TargetedRemovalPhase#click tells the engine to remove_settlement" do
    engine = RecordingEngine.new
    phase = TurnPhase::TargetedRemovalPhase.new(action_type: "sword", klass_name: "SwordTile", pending_orders: [ 1 ])
    phase.click(coord(8, 9), engine)
    assert_equal [ [ :remove_settlement, 8, 9 ] ], engine.sent
  end

  test "CityHallPhase#click tells the engine to place_city_hall" do
    engine = RecordingEngine.new
    phase = TurnPhase::CityHallPhase.new(action_type: "cityhall", klass_name: "CityHallTile")
    phase.click(coord(10, 10), engine)
    assert_equal [ [ :place_city_hall, 10, 10 ] ], engine.sent
  end

  test "TileBuildPhase#click places a wall for a wall tile" do
    engine = RecordingEngine.new
    phase = TurnPhase::TileBuildPhase.new(action_type: "quarry", klass_name: "QuarryTile", walls_placed: 0)
    phase.click(coord(3, 6), engine)
    assert_equal [ [ :place_wall, 3, 6 ] ], engine.sent
  end

  test "TileBuildPhase#click activates a tile build for a build tile" do
    engine = RecordingEngine.new
    phase = TurnPhase::TileBuildPhase.new(action_type: "village", klass_name: "VillageTile")
    phase.click(coord(3, 6), engine)
    assert_equal [ [ :activate_tile_build, 3, 6 ] ], engine.sent
  end

  test "TileBuildPhase#click places a wall for a klass-less quarry action" do
    engine = RecordingEngine.new
    phase = TurnPhase::TileBuildPhase.new(action_type: "quarry", klass_name: nil, walls_placed: 0)
    phase.click(coord(3, 6), engine)
    assert_equal [ [ :place_wall, 3, 6 ] ], engine.sent
  end

  test "FortPhase#click tells the engine to activate_tile_build" do
    engine = RecordingEngine.new
    phase = TurnPhase::FortPhase.new(fort_terrain: "G")
    phase.click(coord(5, 5), engine)
    assert_equal [ [ :activate_tile_build, 5, 5 ] ], engine.sent
  end

  test "base TurnPhase#click rejects clicks (every concrete phase overrides it)" do
    base = TurnPhase.allocate # bare base instance, no subclass behavior
    assert_raises(TurnPhase::InvalidTransition) do
      base.click(coord(0, 0), RecordingEngine.new)
    end
  end
end
