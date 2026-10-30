require "test_helper"

class BazaarScenarioTest < ActiveSupport::TestCase
  # A settlement beside grass, a Bazaar, and the Farm tile (used or not).
  def scenario_with(*tiles, farm_used: false)
    scenario = GameScenario.new(hands: { 0 => "G", 1 => "D" })
    @home = scenario.empty_hex_adjacent_to("G")
    scenario.place_settlement(0, at: @home)
    scenario.give_tile(0, "BazaarTile", from: [ 0, 0 ])
    scenario.give_tile(0, "FarmTile", from: [ 0, 1 ], used: farm_used)
    tiles.each { |klass, opts| scenario.give_tile(0, klass, from: [ 0, 2 ], **(opts || {})) }
    scenario
  end

  test "lists other location tiles it could copy, used or not" do
    scenario = scenario_with
    assert_equal [ [ "FarmTile", nil ] ], scenario.bazaar_entries(0)

    used = scenario_with(farm_used: true)
    assert_equal [ [ "FarmTile", nil ] ], used.bazaar_entries(0)
  end

  test "leaves out Canoe, Nomad, Bonus, Bazaar itself, and tiles that could do nothing" do
    scenario = scenario_with([ "CanoeTile", nil ], [ "OutpostTile", nil ], [ "TempleBonusTile", nil ], [ "TavernTile", nil ])

    assert_equal [ [ "FarmTile", nil ] ], scenario.bazaar_entries(0), "Tavern has no line of 3, so it could do nothing"
  end

  test "a tile picked up this turn cannot be copied" do
    scenario = scenario_with
    spot = scenario.buildable_cells.first
    tile_hex = scenario.neighbors(spot).find { |n| scenario.owner_at(n).nil? }
    scenario.place_tile("OasisTile", at: tile_hex, qty: 2)
    scenario.build_settlement(at: spot)
    assert scenario.holds_tile?(0, klass: "OasisTile")

    assert_not_includes scenario.bazaar_entries(0).map(&:first), "OasisTile"
  end

  test "Bazaar is not selectable with nothing to copy" do
    scenario = GameScenario.new(hands: { 0 => "G", 1 => "D" })
    scenario.give_tile(0, "BazaarTile", from: [ 0, 0 ])

    assert_not_includes scenario.available_tile_actions(0), "BazaarTile"
  end

  test "copying Farm logs two moves, then builds like Farm and uses up Bazaar, not Farm" do
    scenario = scenario_with(farm_used: true)

    scenario.activate_bazaar("FarmTile")

    assert_equal %w[select_action bazaar_copy], scenario.moves.pluck(:action)
    assert_equal [ true, false ], scenario.moves.pluck(:deliberate)
    assert_match(/selected the bazaar action/, scenario.moves.first.message)
    assert_match(/chose to copy the Farm action with Bazaar/, scenario.moves.last.message)
    targets = scenario.buildable_cells
    assert_not_empty targets
    assert(targets.all? { |t| scenario.terrain_at(t) == "G" })

    scenario.build_settlement(at: targets.first)

    assert scenario.tile_used?(0, "BazaarTile")
    assert scenario.tile_used?(0, "FarmTile"), "Farm keeps the state it had (already used)"
    assert_equal 3, scenario.mandatory_remaining
  end

  test "copying leaves an unused tile unused, so it can still be used itself" do
    scenario = scenario_with
    scenario.activate_bazaar("FarmTile")
    scenario.build_settlement(at: scenario.buildable_cells.first)

    assert_not scenario.tile_used?(0, "FarmTile")
    assert_includes scenario.available_tile_actions(0), "FarmTile"
    assert_not_includes scenario.available_tile_actions(0), "BazaarTile"
  end

  test "one undo removes the whole copy, and a tile that is not listed is refused" do
    scenario = scenario_with
    assert_undo_round_trip(scenario) { scenario.activate_bazaar("FarmTile") }

    assert_raises(GameScenario::IllegalMove) { scenario.activate_bazaar("PaddockTile") }
  end

  def with_bazaar(*tiles)
    scenario = GameScenario.new(hands: { 0 => "G", 1 => "D" })
    @home = scenario.empty_hex_adjacent_to("G")
    scenario.place_settlement(0, at: @home)
    scenario.give_tile(0, "BazaarTile", from: [ 0, 0 ])
    tiles.each { |klass, opts| scenario.give_tile(0, klass, from: [ 0, 2 ], **(opts || {})) }
    scenario
  end

  test "Cathedral is offered as one entry per choice, and Build only with a count" do
    scenario = with_bazaar([ "CathedralTile", nil ])
    scenario.give_cathedral_count(0, 0)
    assert_equal [ [ "CathedralTile", "add" ] ], scenario.bazaar_entries(0)

    scenario.give_cathedral_count(0, 2)
    assert_equal [ [ "CathedralTile", "add" ], [ "CathedralTile", "build" ] ], scenario.bazaar_entries(0)
  end

  test "copying Cathedral's add raises the count, uses up Bazaar and leaves Cathedral unused" do
    scenario = with_bazaar([ "CathedralTile", nil ])
    scenario.give_cathedral_count(0, 1)

    scenario.activate_bazaar("CathedralTile", "add")

    assert_equal 2, scenario.cathedral_count(0)
    assert scenario.tile_used?(0, "BazaarTile")
    assert_not scenario.tile_used?(0, "CathedralTile")
    assert_equal %w[select_action bazaar_copy cathedral_add], scenario.moves.pluck(:action)
  end

  test "copying Cathedral's build spends the count; ending it uses up Bazaar; cancelling removes everything" do
    scenario = with_bazaar([ "CathedralTile", nil ])
    scenario.give_cathedral_count(0, 3)
    before = scenario.snapshot

    scenario.activate_bazaar("CathedralTile", "build")
    scenario.end_tile_action
    assert_equal before, scenario.snapshot, "ending before building cancels the whole selection"

    scenario.activate_bazaar("CathedralTile", "build")
    scenario.build_settlement(at: scenario.buildable_cells.first)
    scenario.end_tile_action

    assert_equal 2, scenario.cathedral_count(0)
    assert scenario.tile_used?(0, "BazaarTile")
    assert_not scenario.tile_used?(0, "CathedralTile")
  end

  test "copying Crossroads draws a 3rd card at the end of the turn" do
    with = with_bazaar([ "CrossroadsTile", nil ])
    with.activate_bazaar("CrossroadsTile")
    assert with.tile_used?(0, "BazaarTile")
    with.end_turn
    assert_equal 3, with.hand(0).size

    without = with_bazaar([ "CrossroadsTile", nil ])
    without.end_turn
    assert_equal 2, without.hand(0).size
  end

  test "copying Fort draws a card and builds on it, uses up Bazaar and warns it cannot be undone" do
    scenario = with_bazaar([ "FortTile", nil ])
    assert_equal [ [ "FortTile", nil ] ], scenario.bazaar_entries(0)
    assert_match(/cannot be undone/, scenario.bazaar_entry_labels(0).first)

    scenario.activate_bazaar("FortTile")
    assert_includes scenario.moves.pluck(:action), "draw_fort_card"
    scenario.build_settlement(at: scenario.buildable_cells.first)

    assert scenario.tile_used?(0, "BazaarTile")
    assert_not scenario.tile_used?(0, "FortTile")
  end

  test "copying Paddock moves a settlement and tiles lose their hex as usual, Bazaar like the Paddock it copies" do
    scenario = GameScenario.new(hands: { 0 => "G", 1 => "D" })
    seize, away = [ 0, 9 ], [ 2, 8 ]
    scenario.place_settlement(0, at: seize)
    scenario.give_tile(0, "BazaarTile", from: [ 0, 8 ])   # next to seize, not to away
    scenario.give_tile(0, "PaddockTile", from: [ 0, 10 ]) # next to seize, not to away

    scenario.activate_bazaar("PaddockTile")
    scenario.select_settlement(at: seize)
    scenario.move_step(to: away)

    assert_equal 0, scenario.owner_at(away)
    assert_empty scenario.held_tiles(0, klass: "BazaarTile"), "forfeited when its hex is left, as the used Paddock would be"
    assert_empty scenario.held_tiles(0, klass: "PaddockTile")
    assert_equal 2, scenario.moves.where(action: "forfeit_tile").count
    assert_nil scenario.game_player(0).bazaar_copy, "the copy marker goes once the Bazaar is used"
  end

  test "using the original tile after a copy needs no marker: the next action resolves to the real tile" do
    scenario = scenario_with
    scenario.activate_bazaar("FarmTile")
    scenario.build_settlement(at: scenario.buildable_cells.first)

    scenario.activate_tile(:farm)
    scenario.build_settlement(at: scenario.buildable_cells.first)

    assert scenario.tile_used?(0, "FarmTile")
  end

  test "Scout Cabin cannot be copied once both Scouts are out, and a copy places only what is left" do
    scenario = with_bazaar([ "ScoutCabinTile", nil ])
    scenario.place_scout_for(0, at: scenario.neighbors(@home).find { |n| scenario.owner_at(n).nil? })
    assert_equal [ [ "ScoutCabinTile", nil ] ], scenario.bazaar_entries(0)

    scenario.activate_bazaar("ScoutCabinTile")
    assert_equal 1, scenario.game.current_action["remaining"], "one Scout piece is left"

    full = with_bazaar([ "ScoutCabinTile", nil ])
    2.times { |i| full.place_scout_for(0, at: full.neighbors(@home).reject { |n| full.owner_at(n) }[i]) }
    assert_empty full.bazaar_entries(0)
  end
end
