require "test_helper"

class ScoutCabinScenarioTest < ActiveSupport::TestCase
  # A settlement beside Water, with the Scout Cabin tile in hand.
  def scenario_with_cabin
    scenario = GameScenario.new(hands: { 0 => "G", 1 => "D" })
    @home = scenario.empty_hex_adjacent_to("W")
    scenario.place_settlement(0, at: @home)
    scenario.give_tile(0, "ScoutCabinTile", from: [ 0, 0 ])
    scenario
  end

  def scout_targets(scenario)
    scenario.activate_tile(:scoutcabin)
    scenario.buildable_cells
  end

  test "targets are empty hexes next to your pieces on any terrain but silver or location, water and mountain included" do
    scenario = scenario_with_cabin
    scenario.place_tile("OasisTile", at: scenario.neighbors(@home).find { |n| scenario.owner_at(n).nil? }, qty: 2)
    near = scenario.neighbors(@home)

    targets = scout_targets(scenario)

    assert_not_empty targets
    assert targets.all? { |t| near.include?(t) }, "only hexes touching the settlement"
    assert targets.any? { |t| scenario.terrain_at(t) == "W" }, "water is allowed"
    assert targets.none? { |t| %w[S L].include?(scenario.terrain_at(t)) }
    assert targets.none? { |t| scenario.owner_at(t) }, "only empty hexes"
  end

  test "with no pieces on the board the tile cannot be used" do
    scenario = GameScenario.new(hands: { 0 => "G", 1 => "D" })
    scenario.give_tile(0, "ScoutCabinTile", from: [ 0, 0 ])

    assert_not_includes scenario.available_tile_actions(0), "ScoutCabinTile"
  end

  test "a placed scout is not a build: no supply used, no mandatory progress, no tile pickup, tile still in use" do
    scenario = scenario_with_cabin
    supply = scenario.settlements_remaining(0)
    spot = scout_targets(scenario).first
    loc = scenario.neighbors(spot).find { |n| scenario.owner_at(n).nil? && n != @home }
    scenario.place_tile("OasisTile", at: loc, qty: 2)

    scenario.place_scout(at: spot)

    assert_equal [ spot ], scenario.scouts(0)
    assert_equal supply, scenario.settlements_remaining(0)
    assert_equal 3, scenario.mandatory_remaining
    assert_equal [ @home ], scenario.game.board_contents.settlements_for(0)
    assert_not scenario.holds_tile?(0, klass: "OasisTile"), "scouts do not claim tiles"
    assert_equal 2, scenario.tile_qty(loc)
    assert_not scenario.held_tiles(0, klass: "ScoutCabinTile").first["used"]
    assert_equal 0, scenario.end_trigger_count
  end

  test "the second scout may touch the first scout instead of a settlement, then the action ends" do
    scenario = scenario_with_cabin
    first = scout_targets(scenario).first
    scenario.place_scout(at: first)
    second = scenario.buildable_cells.find { |c| !scenario.neighbors(@home).include?(c) }
    assert second, "a hex reachable only through the first scout is offered"

    scenario.place_scout(at: second)

    assert_equal 2, scenario.scouts(0).size
    assert scenario.held_tiles(0, klass: "ScoutCabinTile").first["used"], "the action ends after 2 scouts"
    assert_not scenario.tile_action_endable?
  end

  test "you can stop after one scout with End action, which is its own undoable move" do
    scenario = scenario_with_cabin
    before = scenario.snapshot
    spot = scout_targets(scenario).first
    scenario.place_scout(at: spot)
    after_scout = scenario.snapshot

    assert scenario.tile_action_endable?
    scenario.end_tile_action
    assert scenario.held_tiles(0, klass: "ScoutCabinTile").first["used"]

    scenario.undo
    assert_equal after_scout, scenario.snapshot, "only End action is undone"
    scenario.undo
    scenario.undo
    assert_equal before, scenario.snapshot
    assert_empty scenario.moves
  end

  test "End action before placing any scout cancels the selection" do
    scenario = scenario_with_cabin
    before = scenario.snapshot
    scenario.activate_tile(:scoutcabin)

    scenario.end_tile_action

    assert_equal before, scenario.snapshot
    assert_empty scenario.moves
  end

  test "scouts count as your settlements for the mandatory build's adjacency" do
    scenario = GameScenario.new(hands: { 0 => "G", 1 => "D" })
    only_scout_touches = lambda do |home, spot|
      scenario.neighbors(spot).select do |n|
        scenario.terrain_at(n) == "G" && scenario.owner_at(n).nil? && n != home && !scenario.neighbors(home).include?(n)
      end
    end
    # A settlement, a hex beside it for the scout, and grass the scout touches but the settlement doesn't.
    home, spot = scenario.empty_hexes("G", 400).lazy.filter_map do |h|
      s = scenario.neighbors(h).find { |n| scenario.owner_at(n).nil? && !%w[S L].include?(scenario.terrain_at(n)) && only_scout_touches.call(h, n).any? }
      [ h, s ] if s
    end.first
    assert spot, "fixed board should offer a scout spot with grass only the scout touches"
    scenario.place_settlement(0, at: home)
    scenario.give_tile(0, "ScoutCabinTile", from: [ 0, 0 ])
    scenario.activate_tile(:scoutcabin)
    scenario.place_scout(at: spot)
    scenario.end_tile_action

    expected = (scenario.neighbors(home) + scenario.neighbors(spot)).select { |c| scenario.terrain_at(c) == "G" && scenario.owner_at(c).nil? && c != spot }

    assert_equal expected.uniq.sort, scenario.buildable_cells.sort
    assert_not_empty(scenario.buildable_cells & only_scout_touches.call(home, spot))
  end

  test "scouts are removed when your turn ends, with a log entry" do
    scenario = scenario_with_cabin
    scenario.place_scout(at: scout_targets(scenario).first)
    scenario.end_tile_action
    scenario.end_turn

    assert_empty scenario.scouts(0)
    assert_equal [ @home ], scenario.game.board_contents.settlements_for(0)
    assert_includes scenario.moves.pluck(:action), "remove_scouts"
  end
end
