require "test_helper"

class CathedralScenarioTest < ActiveSupport::TestCase
  test "picking up the Cathedral tile starts the Cathedral count at 1" do
    scenario = GameScenario.new(hands: { 0 => "G", 1 => "D" })
    spot = scenario.empty_hexes("G", 1).first
    tile_hex = scenario.neighbors(spot).find { |n| scenario.owner_at(n).nil? }
    scenario.place_tile("CathedralTile", at: tile_hex, qty: 1)
    assert_equal 0, scenario.cathedral_count(0)

    scenario.build_settlement(at: spot)

    assert scenario.holds_tile?(0, klass: "CathedralTile", from: tile_hex)
    assert_equal 1, scenario.cathedral_count(0)
    assert_equal 0, scenario.cathedral_count(1)
  end

  test "adding to the count uses the tile for the turn and logs two moves" do
    scenario = GameScenario.new(hands: { 0 => "G", 1 => "D" })
    scenario.give_cathedral(0, count: 1)

    scenario.activate_cathedral("add")

    assert_equal 2, scenario.cathedral_count(0)
    assert scenario.held_tiles(0, klass: "CathedralTile").first["used"]
    assert_equal 3, scenario.mandatory_remaining, "the mandatory action is untouched"
    assert_equal %w[select_action cathedral_add], scenario.moves.pluck(:action)
    assert_equal [ true, false ], scenario.moves.pluck(:deliberate)
  end

  test "one undo reverts adding to the count completely" do
    scenario = GameScenario.new(hands: { 0 => "G", 1 => "D" })
    scenario.give_cathedral(0, count: 1)

    assert_undo_round_trip(scenario) { scenario.activate_cathedral("add") }
    scenario.undo
    assert_empty scenario.moves, "both logged moves are removed together"
  end

  def build_here(scenario)
    scenario.build_settlement(at: scenario.buildable_cells.first)
  end

  test "choosing to build logs two moves and targets the played terrain" do
    scenario = GameScenario.new(hands: { 0 => "G", 1 => "D" })
    scenario.give_cathedral(0, count: 3)

    scenario.activate_cathedral("build")

    assert_equal %w[select_action cathedral_build], scenario.moves.pluck(:action)
    assert_equal [ true, false ], scenario.moves.pluck(:deliberate)
    assert_not_empty scenario.buildable_cells
    assert(scenario.buildable_cells.all? { |cell| scenario.terrain_at(cell) == "G" })
  end

  test "each build spends 1 from the count; ending leaves the mandatory action untouched" do
    scenario = GameScenario.new(hands: { 0 => "G", 1 => "D" })
    scenario.give_cathedral(0, count: 3)
    scenario.activate_cathedral("build")

    build_here(scenario)
    build_here(scenario)
    assert_equal 1, scenario.cathedral_count(0)
    assert_not scenario.held_tiles(0, klass: "CathedralTile").first["used"], "still in use until the action ends"

    scenario.end_tile_action

    assert scenario.held_tiles(0, klass: "CathedralTile").first["used"]
    assert_equal 1, scenario.cathedral_count(0), "the unspent count is kept"
    assert_equal 3, scenario.mandatory_remaining
    assert_equal 2, scenario.game.board_contents.settlements_for(0).size
  end

  test "undo after End action reverts only the End action, then each build, then the whole activation" do
    scenario = GameScenario.new(hands: { 0 => "G", 1 => "D" })
    scenario.give_cathedral(0, count: 3)
    before = scenario.snapshot
    scenario.activate_cathedral("build")
    build_here(scenario)
    after_one = scenario.snapshot
    build_here(scenario)
    after_two = scenario.snapshot
    scenario.end_tile_action

    scenario.undo
    assert_equal after_two, scenario.snapshot, "only End action is undone"
    scenario.undo
    assert_equal after_one, scenario.snapshot
    scenario.undo
    scenario.undo
    assert_equal before, scenario.snapshot, "the last undo removes both activation moves"
    assert_empty scenario.moves
  end

  test "End action before the first build leaves the tile unused and removes the selection" do
    scenario = GameScenario.new(hands: { 0 => "G", 1 => "D" })
    scenario.give_cathedral(0, count: 3)
    before = scenario.snapshot
    scenario.activate_cathedral("build")

    scenario.end_tile_action

    assert_equal before, scenario.snapshot
    assert_empty scenario.moves
  end

  test "End action is offered in the build phase, before and after building" do
    scenario = GameScenario.new(hands: { 0 => "G", 1 => "D" })
    scenario.give_cathedral(0, count: 3)
    scenario.activate_cathedral("build")
    assert scenario.tile_action_endable?

    build_here(scenario)
    assert scenario.tile_action_endable?
  end

  test "building cannot be chosen with a count of 0" do
    scenario = GameScenario.new(hands: { 0 => "G", 1 => "D" })
    scenario.give_cathedral(0, count: 0)

    assert_raises(GameScenario::IllegalMove) { scenario.activate_cathedral("build") }
    assert_empty scenario.moves
  end

  test "spending the last of the count ends the action" do
    scenario = GameScenario.new(hands: { 0 => "G", 1 => "D" })
    scenario.give_cathedral(0, count: 2)
    scenario.activate_cathedral("build")

    build_here(scenario)
    build_here(scenario)

    assert_equal 0, scenario.cathedral_count(0)
    assert scenario.held_tiles(0, klass: "CathedralTile").first["used"]
    assert_not scenario.tile_action_endable?
  end

  test "a two-card hand is locked to the terrain of the first build" do
    scenario = GameScenario.new(hands: { 0 => %w[G D], 1 => "D" })
    scenario.give_cathedral(0, count: 3)
    scenario.activate_cathedral("build")
    assert_equal %w[D G], scenario.buildable_cells.map { |c| scenario.terrain_at(c) }.uniq.sort

    build_here(scenario)
    locked = scenario.terrain_at(scenario.game.board_contents.settlements_for(0).first)

    assert(scenario.buildable_cells.all? { |cell| scenario.terrain_at(cell) == locked })
  end

  test "a lost tile leaves the count idle and cannot be activated" do
    scenario = GameScenario.new(hands: { 0 => "G", 1 => "D" })
    scenario.give_cathedral(0, count: 2)
    scenario.game.game_players.find_by(order: 0).update!(tiles: [])

    assert_raises(GameScenario::IllegalMove) { scenario.activate_cathedral("add") }
    assert_equal 2, scenario.cathedral_count(0)
  end
end
