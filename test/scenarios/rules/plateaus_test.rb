require "test_helper"

# Plateaus decree: any build next to empty mountains may be moved to one of them. The choice is
# pending (nothing else can be done) until a mountain or the built hex is clicked.
class PlateausScenarioTest < ActiveSupport::TestCase
  def plateau_scenario(decree: { "name" => "plateaus" })
    scenario = GameScenario.new(hands: { 0 => "G", 1 => "D" })
    scenario.game.update!(decree:)
    scenario.game.board = nil
    scenario
  end

  # A grass hex touching mountains, and a grass hex touching none.
  def spots(scenario)
    contents = scenario.game.tap(&:instantiate).board_contents
    grass = BoardState::MAIN_CELLS.select { |c| scenario.terrain_at(c) == "G" }
    near = grass.find { |c| contents.neighbors(*c).any? { |n| scenario.terrain_at(n) == "M" } }
    far = grass.find { |c| contents.neighbors(*c).none? { |n| scenario.terrain_at(n) == "M" } }
    mountains = contents.neighbors(*near).select { |n| scenario.terrain_at(n) == "M" }
    [ near, far, mountains ]
  end

  test "building next to mountains highlights them and the built hex, and pauses everything else" do
    scenario = plateau_scenario
    near, _, mountains = spots(scenario)
    scenario.build_settlement(at: near)

    assert_equal ([ near ] + mountains).to_set, scenario.buildable_cells.to_set
    assert_match(/move to mountain or click again/, scenario.turn_state)
    assert_not scenario.turn_endable?
    assert_raises(GameScenario::IllegalMove) { scenario.end_turn }
  end

  test "clicking a mountain moves the settlement there and logs it" do
    scenario = plateau_scenario
    near, _, mountains = spots(scenario)
    scenario.build_settlement(at: near)
    scenario.build_settlement(at: mountains.first)

    assert_equal 0, scenario.owner_at(mountains.first)
    assert_nil scenario.owner_at(near)
    assert_equal "plateau_move", scenario.moves.last.action
    assert_equal Game::MANDATORY_COUNT - 1, scenario.mandatory_remaining
    assert_no_match(/click again/, scenario.turn_state)
  end

  test "clicking the built hex again leaves it, with no log entry" do
    scenario = plateau_scenario
    near, = spots(scenario)
    scenario.build_settlement(at: near)
    scenario.build_settlement(at: near)

    assert_equal 0, scenario.owner_at(near)
    assert_not_includes scenario.moves.pluck(:action), "plateau_move"
    assert_no_match(/click again/, scenario.turn_state)
  end

  test "a build with no mountain next to it, or without the decree, is not paused" do
    scenario = plateau_scenario
    _, far, = spots(scenario)
    scenario.build_settlement(at: far)
    assert_no_match(/click again/, scenario.turn_state)

    plain = plateau_scenario(decree: nil)
    near, = spots(plain)
    plain.build_settlement(at: near)
    assert_no_match(/click again/, plain.turn_state)
  end

  test "undo takes back the whole build, moved or not" do
    scenario = plateau_scenario
    near, _, mountains = spots(scenario)
    scenario.build_settlement(at: near)
    scenario.build_settlement(at: mountains.first)
    scenario.undo

    assert_nil scenario.owner_at(near)
    assert_nil scenario.owner_at(mountains.first)
    assert_equal Game::MANDATORY_COUNT, scenario.mandatory_remaining

    scenario.build_settlement(at: near)
    scenario.undo
    assert_nil scenario.owner_at(near)
    assert_no_match(/click again/, scenario.turn_state)
  end

  test "tile builds are offered the move too" do
    scenario = plateau_scenario
    near, _, mountains = spots(scenario)
    scenario.give_tile(0, "FarmTile", from: scenario.neighbors(mountains.first).first) # stays adjacent after the move
    scenario.activate_tile(:farm)
    scenario.build_settlement(at: near)
    assert_match(/move to mountain or click again/, scenario.turn_state)

    scenario.build_settlement(at: mountains.first)
    assert_equal 0, scenario.owner_at(mountains.first)
    assert scenario.tile_used?(0, "FarmTile")
  end

  test "a warrior placed by Barracks may move to a mountain too" do
    scenario = plateau_scenario
    near, _, mountains = spots(scenario)
    scenario.give_warriors(0, 1)
    scenario.give_tile(0, "BarracksTile", from: [ 0, 0 ])
    scenario.activate_tile(:barracks)
    scenario.move_meeple_step(to: near)
    assert_match(/move to mountain or click again/, scenario.turn_state)

    scenario.move_meeple_step(to: mountains.first)
    assert_equal "warrior", scenario.meeple_at(mountains.first)
    assert_nil scenario.owner_at(near)
  end

  # Board 21: Mountain Station (2,3) and Scout Cabin (4,3) both touch the mountain at (3,3). The flowers
  # at (2,4) touch only the Station, and the mountain at (3,4) touches neither location hex.
  def board_21_scenario(decree: { "name" => "plateaus" }, goals: [])
    scenario = GameScenario.new(boards: [ [ 21, 0 ], [ 5, 0 ], [ 0, 0 ], [ 4, 0 ] ], hands: { 0 => "F", 1 => "D" }, goals:)
    scenario.game.update!(decree:)
    scenario.game.board = nil
    scenario.place_tile("MountainStationTile", at: [ 2, 3 ])
    scenario.place_tile("ScoutCabinTile", at: [ 4, 3 ])
    scenario
  end

  test "moving onto a mountain touching two location hexes acquires both tiles" do
    scenario = board_21_scenario
    scenario.build_settlement(at: [ 2, 4 ]) # flowers next to the Mountain Station
    assert scenario.holds_tile?(0, klass: "MountainStationTile", from: [ 2, 3 ])
    assert_not scenario.holds_tile?(0, klass: "ScoutCabinTile")

    scenario.build_settlement(at: [ 3, 3 ])

    assert scenario.holds_tile?(0, klass: "MountainStationTile", from: [ 2, 3 ])
    assert scenario.holds_tile?(0, klass: "ScoutCabinTile", from: [ 4, 3 ])
  end

  test "the build and the move are both logged, each followed by its own pickup" do
    scenario = board_21_scenario
    scenario.build_settlement(at: [ 2, 4 ])
    scenario.build_settlement(at: [ 3, 3 ])

    assert_equal %w[build pick_up_tile plateau_move pick_up_tile], scenario.moves.last(4).pluck(:action)
  end

  test "moving away from a location hex forfeits its tile" do
    scenario = board_21_scenario
    scenario.build_settlement(at: [ 2, 4 ])
    scenario.build_settlement(at: [ 3, 4 ]) # touches no location hex

    assert_not scenario.holds_tile?(0, klass: "MountainStationTile")
    assert_equal %w[build pick_up_tile plateau_move forfeit_tile], scenario.moves.last(4).pluck(:action)
  end

  test "undo takes back the build, the move and both pickups" do
    scenario = board_21_scenario
    scenario.build_settlement(at: [ 2, 4 ])
    scenario.build_settlement(at: [ 3, 3 ])
    scenario.undo

    assert_nil scenario.owner_at([ 3, 3 ])
    assert_not scenario.holds_tile?(0, klass: "MountainStationTile")
    assert_not scenario.holds_tile?(0, klass: "ScoutCabinTile")
    assert_equal 2, scenario.tile_qty([ 2, 3 ])
    assert_equal 2, scenario.tile_qty([ 4, 3 ])
  end

  test "moving away from a location hex keeps a Nomad tile" do
    scenario = board_21_scenario
    scenario.give_tile(0, "SwordTile", from: [ 2, 3 ])
    scenario.build_settlement(at: [ 2, 4 ])
    scenario.build_settlement(at: [ 3, 4 ])

    assert scenario.holds_tile?(0, klass: "SwordTile")
    assert_not_includes scenario.moves.pluck(:action), "forfeit_tile"
  end

  test "building on the mountain between two location hexes picks up both" do
    scenario = board_21_scenario(decree: nil)
    scenario.give_tile(0, "DonationMountainTile", from: [ 0, 0 ])
    scenario.activate_tile(:donationmountain)
    scenario.build_settlement(at: [ 3, 3 ])

    assert scenario.holds_tile?(0, klass: "MountainStationTile", from: [ 2, 3 ])
    assert scenario.holds_tile?(0, klass: "ScoutCabinTile", from: [ 4, 3 ])
  end

  test "with Plateaus, moving off the mountain between two location hexes loses both" do
    scenario = board_21_scenario
    scenario.give_tile(0, "DonationMountainTile", from: [ 0, 0 ])
    scenario.activate_tile(:donationmountain)
    scenario.build_settlement(at: [ 3, 3 ])
    scenario.build_settlement(at: [ 3, 4 ]) # touches neither location hex

    assert_not scenario.holds_tile?(0, klass: "MountainStationTile")
    assert_not scenario.holds_tile?(0, klass: "ScoutCabinTile")
    assert_equal %w[forfeit_tile forfeit_tile], scenario.moves.last(2).pluck(:action)
  end

  test "emptying one location by the build and another by the move gives each Canoe two reactions" do
    scenario = board_21_scenario
    scenario.place_tile("MountainStationTile", at: [ 2, 3 ], qty: 1)
    scenario.place_tile("ScoutCabinTile", at: [ 4, 3 ], qty: 1)
    scenario.give_tile(1, "CanoeTile", from: [ 0, 0 ])
    scenario.build_settlement(at: [ 2, 4 ])
    scenario.build_settlement(at: [ 3, 3 ])

    assert_equal [ 1, 1 ], scenario.game.reload.turn_phase.holders
  end

  # Goals are decided where the piece is built. Only Mayors is checked again after the move.

  test "Ambassadors counts at the build even if the settlement moves away" do
    scenario = board_21_scenario(goals: [ "ambassadors" ])
    scenario.place_settlement(1, at: [ 2, 5 ]) # touches the flowers (2,4), not the mountain (3,3)
    scenario.build_settlement(at: [ 2, 4 ])
    scenario.build_settlement(at: [ 3, 3 ])
    assert_equal 1, scenario.score_for("ambassadors", 0)
  end

  test "Ambassadors does not count for an opponent met only after the move" do
    scenario = board_21_scenario(goals: [ "ambassadors" ])
    scenario.place_settlement(1, at: [ 4, 4 ]) # touches the mountain (3,3) only
    scenario.build_settlement(at: [ 2, 4 ])
    scenario.build_settlement(at: [ 3, 3 ])
    assert_equal 0, scenario.score_for("ambassadors", 0)
  end

  test "Shepherds counts at the build only, not again for the move" do
    scenario = board_21_scenario(goals: [ "shepherds" ])
    scenario.place_settlement(1, at: [ 2, 5 ]) # the only empty flowers next to (2,4)
    scenario.build_settlement(at: [ 2, 4 ])
    assert_equal 2, scenario.score_for("shepherds", 0)

    scenario.build_settlement(at: [ 3, 3 ]) # move: no second score for the mountain
    assert_equal 2, scenario.score_for("shepherds", 0)
  end

  test "Mayors counts at the build and again at the move, so one build can claim two rows" do
    scenario = board_21_scenario(goals: [ "mayors" ])
    [ [ 2, 5 ], [ 2, 6 ], [ 2, 7 ], [ 3, 1 ], [ 3, 2 ], [ 3, 4 ] ].each { |at| scenario.place_settlement(0, at:) }
    scenario.build_settlement(at: [ 2, 4 ]) # row 2 now has 4
    assert_equal 1, scenario.moves.pluck(:action).count("claim_mayor")

    scenario.build_settlement(at: [ 3, 3 ]) # row 3 now has 4, row 2 keeps its marker
    assert_equal 2, scenario.moves.pluck(:action).count("claim_mayor")
  end

  test "Families counts the first 3 builds where they were built, not where Plateaus moved them" do
    scenario = board_21_scenario(goals: [ "families" ])
    # (1,3), (2,4) and (3,4) lie on a line. The third is built at (2,5), on no line, then moved to (3,4).
    [ [ 1, 3 ], [ 2, 4 ] ].each { |at| scenario.place_settlement(0, at:) }
    scenario.set_mandatory(1)
    scenario.game.turn_phase = TurnPhase::MandatoryBuildPhase.new(chosen_terrain: "F", builds: [ [ 1, 3 ], [ 2, 4 ] ])
    scenario.game.save!

    scenario.build_settlement(at: [ 2, 5 ])
    scenario.build_settlement(at: [ 3, 4 ])
    assert_equal 0, scenario.score_for("families", 0)
  end

  test "Families scores for a line built at the build hexes even if the last one moves away" do
    scenario = board_21_scenario(goals: [ "families" ])
    [ [ 2, 5 ], [ 2, 6 ] ].each { |at| scenario.place_settlement(0, at:) }
    scenario.set_mandatory(1)
    scenario.game.turn_phase = TurnPhase::MandatoryBuildPhase.new(chosen_terrain: "F", builds: [ [ 2, 5 ], [ 2, 6 ] ])
    scenario.game.save!

    scenario.build_settlement(at: [ 2, 4 ])
    scenario.build_settlement(at: [ 3, 3 ])
    assert_equal 2, scenario.score_for("families", 0)
  end
end
