require "test_helper"

# Tracer for a Tier-1 (board-derived) task: Advance is recomputed from the
# board via Scoring::Tasks::Advance, not accumulated during play, so it can
# be exercised with direct settlement placement and read back through the
# Scoring seam.
class AdvanceScenarioTest < ActiveSupport::TestCase
  test "7 settlements on one edge of the board scores 9 advance points" do
    scenario = GameScenario.new(tasks: [ "advance" ])
    7.times { |col| scenario.place_settlement(0, at: [ 0, col ]) }

    assert_equal 9, scenario.score_for("advance", 0)
  end

  test "7 settlements on two edges of the board scores 9 advance points" do
    scenario = GameScenario.new(tasks: [ "advance" ])
    7.times { |col| scenario.place_settlement(0, at: [ 0, col ]) }
    7.times { |col| scenario.place_settlement(1, at: [ 1, col ]) }

    assert_equal 9, scenario.score_for("advance", 0)
  end

  test "6 settlements on one edge of the board scores no advance points" do
    scenario = GameScenario.new(tasks: [ "advance" ])
    6.times { |col| scenario.place_settlement(0, at: [ 0, col ]) }

    assert_equal 0, scenario.score_for("advance", 0)
  end
end
