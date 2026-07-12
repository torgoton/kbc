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

  test "base TurnPhase#click rejects clicks (every concrete phase overrides it)" do
    base = TurnPhase.allocate # bare base instance, no subclass behavior
    assert_raises(TurnPhase::InvalidTransition) do
      base.click(coord(0, 0), RecordingEngine.new)
    end
  end
end
