require "test_helper"

# Nomad::OutpostTile is activated via its own route (not the normal tile
# action flow) to skip the adjacency requirement for the current build.
class OutpostTileTest < ActiveSupport::TestCase
  FAR_SETTLEMENT = [ 19, 19 ].freeze
  NON_ADJACENT_TARGET = [ 0, 7 ].freeze

  test "activating skips the adjacency requirement for the current build" do
    scenario = GameScenario.new(hands: { 0 => "G" })
    scenario.place_settlement(0, at: FAR_SETTLEMENT)
    scenario.give_tile(0, "OutpostTile", from: [ 0, 0 ])

    assert_equal "G", scenario.terrain_at(NON_ADJACENT_TARGET)
    assert_not_includes scenario.legal_builds(0), NON_ADJACENT_TARGET

    scenario.activate_outpost
    scenario.build_settlement(at: NON_ADJACENT_TARGET)

    assert_equal 0, scenario.owner_at(NON_ADJACENT_TARGET)
    assert_not_includes scenario.usable_tiles(0), "OutpostTile"
  end

  test "is never offered as a selectable tile action" do
    scenario = GameScenario.new
    scenario.give_tile(0, "OutpostTile", from: [ 0, 0 ])

    assert_not_includes scenario.available_tile_actions(0), "OutpostTile"
  end
end
