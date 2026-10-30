require "test_helper"

# Harvest Silo: after the final round each player, in turn order, gets one choice per Silo
# they have a settlement next to (counted when regular play ends): build, move, or skip.
# Board 20's Silo is at [7, 4]; every neighbour of it is Farmland.
class SiloScenarioTest < ActiveSupport::TestCase
  SILO_NEIGHBOURS = [ [ 7, 3 ], [ 7, 5 ], [ 6, 4 ] ].freeze
  SILO_2_NEIGHBOUR = [ 6, 16 ].freeze # next to board 21's Silo at [6, 17]

  def scenario
    GameScenario.new(boards: GameScenario::HARVEST_BOARDS)
  end

  test "a player has one Silo for each Silo hex next to any of their settlements" do
    s = scenario
    s.place_settlement(0, at: SILO_NEIGHBOURS[0])
    s.place_settlement(0, at: SILO_NEIGHBOURS[1])

    assert_equal 1, s.silos(0)
    assert_equal 0, s.silos(1)
  end

  test "the game goes to the Silo round instead of ending when someone has a Silo" do
    s = scenario
    s.place_settlement(0, at: SILO_NEIGHBOURS[0])

    s.finish_final_round

    assert_equal "playing", s.state
    assert_equal 0, s.current_order
    assert_equal({ "type" => "silo", "silo" => 1, "of" => 1 }, s.phase)
  end

  test "the game ends as before when nobody has a Silo" do
    s = scenario

    s.finish_final_round

    assert_equal "completed", s.state
  end

  test "skipping the only Silo ends the game when nobody else has one" do
    s = scenario
    s.place_settlement(0, at: SILO_NEIGHBOURS[0])
    s.finish_final_round

    s.silo_choice("skip")

    assert_equal "completed", s.state
  end

  test "skipping a Silo moves on to the player's next Silo" do
    s = scenario
    s.place_settlement(0, at: SILO_NEIGHBOURS[0])
    s.place_settlement(0, at: SILO_2_NEIGHBOUR)
    s.finish_final_round
    assert_equal({ "type" => "silo", "silo" => 1, "of" => 2 }, s.phase)

    s.silo_choice("skip")

    assert_equal 0, s.current_order
    assert_equal({ "type" => "silo", "silo" => 2, "of" => 2 }, s.phase)
  end

  test "a player's last Silo choice passes to the next player with a Silo" do
    s = scenario
    s.place_settlement(0, at: SILO_NEIGHBOURS[0])
    s.place_settlement(1, at: SILO_2_NEIGHBOUR)
    s.finish_final_round

    s.silo_choice("skip")

    assert_equal "playing", s.state
    assert_equal 1, s.current_order
    assert_equal({ "type" => "silo", "silo" => 1, "of" => 1 }, s.phase)
  end

  test "undoing a skip returns to the same prompt" do
    s = scenario
    s.place_settlement(0, at: SILO_NEIGHBOURS[0])
    s.place_settlement(0, at: SILO_2_NEIGHBOUR)
    s.finish_final_round

    assert_undo_round_trip(s) { s.silo_choice("skip") }
  end

  def adjacent_buildable(s, to:)
    s.neighbors(to).select do |r, c|
      s.owner_at([ r, c ]).nil? && Tiles::Tile::BUILDABLE_TERRAIN.include?(s.terrain_at([ r, c ]))
    end
  end

  def silo_build_scenario
    s = scenario
    s.place_settlement(0, at: SILO_NEIGHBOURS[0])
    s.finish_final_round
    s.silo_choice("build")
    s
  end

  test "Silo build targets are the empty buildable hexes next to your settlements, with no fallback" do
    s = silo_build_scenario

    assert_equal adjacent_buildable(s, to: SILO_NEIGHBOURS[0]).sort, s.buildable_cells.sort
  end

  test "a built settlement counts as an anchor for the next build" do
    s = silo_build_scenario
    first = s.buildable_cells.first
    s.build_settlement(at: first)

    assert_includes s.buildable_cells, (adjacent_buildable(s, to: first) - s.neighbors(SILO_NEIGHBOURS[0])).first
  end

  test "building uses supply, and after 3 settlements the player must end the action" do
    s = silo_build_scenario
    before = s.settlements_remaining(0)

    3.times { s.build_settlement(at: s.buildable_cells.first) }

    assert_equal before - 3, s.settlements_remaining(0)
    assert_empty s.buildable_cells
    assert s.turn_endable?
    assert_equal "playing", s.state
    s.end_turn
    assert_equal "completed", s.state
  end

  test "the last build can still be undone before ending the turn" do
    s = silo_build_scenario
    2.times { s.build_settlement(at: s.buildable_cells.first) }

    assert_undo_round_trip(s) { s.build_settlement(at: s.buildable_cells.first) }
  end

  test "the turn-state line follows the Silo steps" do
    s = scenario
    s.place_settlement(0, at: SILO_NEIGHBOURS[0])
    s.finish_final_round
    handle = "scenario-#{s.game.id}-p0"
    assert_equal "For Silo 1 (of 1): #{handle} must choose to build or move, or skip", s.turn_state

    s.silo_choice("build")
    assert_equal "For Silo 1 (of 1): #{handle} may build (3 left)", s.turn_state

    3.times { s.build_settlement(at: s.buildable_cells.first) }
    assert_equal "For Silo 1 (of 1): #{handle} must end the action", s.turn_state
  end

  test "End action stops a Silo build early" do
    s = silo_build_scenario
    s.build_settlement(at: s.buildable_cells.first)

    s.end_tile_action

    assert_equal "completed", s.state
  end

  test "a Silo build with no settlements in supply has no targets" do
    s = silo_build_scenario
    s.set_settlements(0, 0)

    assert_empty s.buildable_cells
  end

  test "a Silo build picks up a location tile like any build" do
    s = scenario
    s.place_settlement(0, at: SILO_NEIGHBOURS[0])
    s.place_settlement(0, at: [ 3, 8 ]) # two hexes from the Bazaar at [3, 6]
    s.place_tile("BazaarTile", at: [ 3, 6 ])
    s.finish_final_round
    s.silo_choice("build")

    s.build_settlement(at: [ 3, 7 ])

    assert s.holds_tile?(0, klass: "BazaarTile")
  end

  test "undoing a Silo build restores the board and supply" do
    s = silo_build_scenario

    assert_undo_round_trip(s) { s.build_settlement(at: s.buildable_cells.first) }
  end

  FAR_SETTLEMENT = [ 3, 8 ].freeze

  def silo_move_scenario
    s = scenario
    s.place_settlement(0, at: SILO_NEIGHBOURS[0])
    s.place_settlement(0, at: FAR_SETTLEMENT)
    s.finish_final_round
    s.silo_choice("move")
    s
  end

  test "a Silo move can pick any settlement that has somewhere to go" do
    s = silo_move_scenario

    assert_equal [ SILO_NEIGHBOURS[0], FAR_SETTLEMENT ].sort, s.buildable_cells.sort
  end

  test "a moved settlement goes next to your other settlements, not next to where it started" do
    s = silo_move_scenario
    s.select_settlement(at: SILO_NEIGHBOURS[0])

    assert_equal adjacent_buildable(s, to: FAR_SETTLEMENT).sort, s.buildable_cells.sort
  end

  test "a Silo move relocates the settlement and the choice ends after 3 moves" do
    s = silo_move_scenario
    s.select_settlement(at: SILO_NEIGHBOURS[0])
    dest = s.buildable_cells.first

    s.move_step(to: dest)

    assert_nil s.owner_at(SILO_NEIGHBOURS[0])
    assert_equal 0, s.owner_at(dest)
    assert_equal "silo", s.phase["type"]
    assert_equal 2, s.phase["remaining"]
  end

  test "moving away from a Silo does not change the number of Silo choices" do
    s = silo_move_scenario
    s.select_settlement(at: SILO_NEIGHBOURS[0])
    s.move_step(to: s.buildable_cells.first)

    assert_equal 0, s.silos(0)
    assert_equal({ "type" => "silo", "silo" => 1, "of" => 1, "mode" => "move", "remaining" => 2 }, s.phase)
  end

  test "after three Silo moves the player must end the action" do
    s = silo_move_scenario
    3.times do
      s.select_settlement(at: s.buildable_cells.first)
      s.move_step(to: s.buildable_cells.first)
    end

    assert s.turn_endable?
    s.end_turn
    assert_equal "completed", s.state
  end

  test "Silo moves can use a warrior, a ship or a wagon but not a City Hall" do
    s = silo_move_scenario
    s.place_warrior(0, at: [ 8, 3 ])
    s.place_settlement(0, at: [ 6, 4 ])
    s.place_ship(0, at: [ 5, 5 ])
    s.place_wagon(0, at: [ 8, 5 ])
    s.place_city_hall_hex(0, at: [ 1, 1 ])

    movable = s.buildable_cells
    [ [ 8, 3 ], [ 5, 5 ], [ 8, 5 ] ].each { |cell| assert_includes movable, cell }
    refute_includes movable, [ 1, 1 ]
  end

  test "a moved ship keeps its kind and uses the settlement terrain rule" do
    s = silo_move_scenario
    s.place_settlement(0, at: [ 6, 4 ])
    s.place_ship(0, at: [ 5, 5 ])
    s.select_settlement(at: [ 5, 5 ])
    dest = s.buildable_cells.first
    assert_includes Tiles::Tile::BUILDABLE_TERRAIN, s.terrain_at(dest)

    s.move_step(to: dest)

    assert_equal "ship", s.meeple_at(dest)
  end

  test "End action stops a Silo move early" do
    s = silo_move_scenario
    s.select_settlement(at: SILO_NEIGHBOURS[0])
    s.move_step(to: s.buildable_cells.first)

    s.end_tile_action

    assert_equal "completed", s.state
  end

  test "a Silo move forfeits a tile whose location the settlement leaves" do
    s = silo_move_scenario
    s.place_settlement(0, at: [ 3, 7 ])
    s.give_tile(0, "BazaarTile", from: [ 3, 6 ])
    s.select_settlement(at: [ 3, 7 ])

    s.move_step(to: s.buildable_cells.first)

    refute s.holds_tile?(0, klass: "BazaarTile")
  end

  test "undoing a Silo move step restores the board" do
    s = silo_move_scenario
    s.select_settlement(at: SILO_NEIGHBOURS[0])

    assert_undo_round_trip(s) { s.move_step(to: s.buildable_cells.first) }
  end

  test "the 3rd build of a Silo starts the next Silo; the last Silo waits for End turn" do
    s = scenario
    s.place_settlement(0, at: SILO_NEIGHBOURS[0])
    s.place_settlement(0, at: SILO_2_NEIGHBOUR)
    s.finish_final_round
    s.silo_choice("build")

    3.times { s.build_settlement(at: s.buildable_cells.first) }
    assert_equal({ "type" => "silo", "silo" => 2, "of" => 2 }, s.phase)
    refute s.turn_endable?

    s.silo_choice("build")
    3.times { s.build_settlement(at: s.buildable_cells.first) }
    assert s.turn_endable?
  end

  test "undoing the 3rd build returns to that Silo's build" do
    s = scenario
    s.place_settlement(0, at: SILO_NEIGHBOURS[0])
    s.place_settlement(0, at: SILO_2_NEIGHBOUR)
    s.finish_final_round
    s.silo_choice("build")
    2.times { s.build_settlement(at: s.buildable_cells.first) }

    assert_undo_round_trip(s) { s.build_settlement(at: s.buildable_cells.first) }
  end
end
