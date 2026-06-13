require "test_helper"

# Tracer for a Tier-2 (callback-derived) goal: Families is scored inside the
# turn engine once a player's 3 mandatory builds are complete, not recomputed
# from the board, so it must be driven end-to-end through real build actions
# and read back through the Scoring seam. Mirrors goals/ambassadors_test.rb.
class FamiliesScenarioTest < ActiveSupport::TestCase
  test "building all 3 mandatory settlements in a straight line scores a families point" do
    scenario = GameScenario.new(goals: [ "families" ], hands: { 0 => "G", 1 => "D" })
    row, col = find_grass_run(scenario)
    raise "fixed board should offer 3 consecutive grass hexes" unless row

    scenario.build_settlement(at: [ row, col ])
    scenario.build_settlement(at: [ row, col + 1 ])
    scenario.build_settlement(at: [ row, col + 2 ])

    assert_equal 2, scenario.score_for("families", 0)
  end

  test "building the 3 mandatory settlements off a straight line scores no families point" do
    scenario = GameScenario.new(goals: [ "families" ], hands: { 0 => "G", 1 => "D" })
    row, col = find_grass_run(scenario)
    raise "fixed board should offer 3 consecutive grass hexes" unless row
    kink = [ row - 1, col ]
    raise "fixed board should offer a non-collinear grass hex above the run" unless
      scenario.terrain_at(kink) == "G" && scenario.owner_at(kink).nil?

    scenario.build_settlement(at: [ row, col ])
    scenario.build_settlement(at: [ row, col + 1 ])
    scenario.build_settlement(at: kink)

    assert_equal 0, scenario.score_for("families", 0)
  end

  private

  # A row with 3 consecutive empty grass hexes, where the hex directly above
  # the first one is also empty grass (used by the "off a straight line" test
  # as a non-collinear third build).
  def find_grass_run(scenario)
    (1..19).each do |row|
      (0..17).each do |col|
        next unless [ col, col + 1, col + 2 ].all? do |c|
          scenario.terrain_at([ row, c ]) == "G" && scenario.owner_at([ row, c ]).nil?
        end
        next unless scenario.terrain_at([ row - 1, col ]) == "G" && scenario.owner_at([ row - 1, col ]).nil?

        return [ row, col ]
      end
    end
    nil
  end
end
