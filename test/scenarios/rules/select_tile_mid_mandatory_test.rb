require "test_helper"

# Tiles may only be picked before the first mandatory build or once none remain; the server
# enforces it even if a stale page still shows the tile as clickable.
class SelectTileMidMandatoryTest < ActiveSupport::TestCase
  test "select_action is rejected after the first mandatory build" do
    scenario = GameScenario.new(hands: { 0 => "D" })
    scenario.game.update!(decree: { "name" => "island", "map" => 0 })
    scenario.give_tile(0, "TowerTile", from: [ 16, 4 ])
    scenario.build_settlement(at: scenario.buildable_cells.find { |r, _| r >= Boards::Island::ROW })

    result = TurnEngine.new(scenario.game.reload).select_action("tower")

    assert_equal "Not available", result
    assert_equal "mandatory", scenario.game.reload.current_action["type"]
  end
end
