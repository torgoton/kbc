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

  test "while active, buildable cells span the whole terrain, not just hexes adjacent to a settlement" do
    scenario = GameScenario.new(hands: { 0 => "G" })
    scenario.place_settlement(0, at: FAR_SETTLEMENT)
    scenario.give_tile(0, "OutpostTile", from: [ 0, 0 ])

    scenario.activate_outpost
    cells = scenario.buildable_cells

    assert_includes cells, NON_ADJACENT_TARGET
    cells.each { |cell| assert_equal "G", scenario.terrain_at(cell) }
  end

  test "the adjacency waiver is spent by one build; the next build needs adjacency again" do
    scenario = GameScenario.new(hands: { 0 => "G" })
    scenario.give_tile(0, "OutpostTile", from: [ 0, 0 ])

    scenario.activate_outpost
    scenario.build_settlement(at: NON_ADJACENT_TARGET)

    far_grass = scenario.empty_hexes("G", 400).find do |hex|
      !scenario.neighbors(NON_ADJACENT_TARGET).include?(hex)
    end
    assert_not_includes scenario.legal_builds(0), far_grass
    assert_raises(GameScenario::IllegalMove) { scenario.build_settlement(at: far_grass) }
  end

  test "with a tile action selected, the waiver applies only to that tile's build" do
    scenario = GameScenario.new
    scenario.place_settlement(0, at: FAR_SETTLEMENT)
    scenario.give_tile(0, "FarmTile", from: [ 0, 0 ])   # FarmTile builds on Grass
    scenario.give_tile(0, "OutpostTile", from: [ 1, 1 ])

    scenario.activate_tile(:farm)
    assert_not_includes scenario.buildable_cells, NON_ADJACENT_TARGET # Farm still needs adjacency

    scenario.activate_outpost
    assert_includes scenario.buildable_cells, NON_ADJACENT_TARGET     # waived for this Farm build

    scenario.build_settlement(at: NON_ADJACENT_TARGET)

    assert_equal 0, scenario.owner_at(NON_ADJACENT_TARGET)
    assert_not_includes scenario.usable_tiles(0), "FarmTile"
  end

  test "activating and building round-trip through undo" do
    scenario = GameScenario.new(hands: { 0 => "G" })
    scenario.give_tile(0, "OutpostTile", from: [ 0, 0 ])

    # The round-trip replays activate_outpost, leaving the waiver active for the
    # build round-trip that follows.
    assert_undo_round_trip(scenario) { scenario.activate_outpost }
    assert_undo_round_trip(scenario) { scenario.build_settlement(at: NON_ADJACENT_TARGET) }
  end
end
