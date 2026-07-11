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
end
