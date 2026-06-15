require "test_helper"

class TurnPhaseTest < ActiveSupport::TestCase
  test "mandatory build transition records chosen terrain and build coordinates" do
    phase = TurnPhase.deserialize({ "type" => "mandatory" })

    result = phase.transition(
      TurnPhase::Events::BuildChosen.new(coordinate: [ 3, 4 ]),
      TurnPhase::Facts::BuildChoice.new(locked_terrain: "G")
    )

    assert_instance_of TurnPhase::MandatoryBuildPhase, result.next_phase
    assert_equal(
      { "type" => "mandatory", "chosen_terrain" => "G", "builds" => [ [ 3, 4 ] ] },
      result.next_phase.serialize
    )
  end

  test "mandatory tile selection can enter tile build phase" do
    phase = TurnPhase.deserialize({ "type" => "mandatory" })
    selected_phase = TurnPhase::TileBuildPhase.new(action_type: "oasis", klass_name: "OasisTile")

    result = phase.transition(
      TurnPhase::Events::TileActionSelected.new,
      TurnPhase::Facts::TileActionSelection.new(selected_phase: selected_phase)
    )

    assert_instance_of TurnPhase::TileBuildPhase, result.next_phase
    assert_equal(
      { "type" => "oasis", "klass" => "OasisTile" },
      result.next_phase.serialize
    )
  end

  test "deserializing a build-family current_action returns tile build phase" do
    phase = TurnPhase.deserialize({ "type" => "donationdesert", "klass" => "DonationDesertTile", "remaining" => 3 })

    assert_instance_of TurnPhase::TileBuildPhase, phase
    assert_equal "donationdesert", phase.type
    assert_equal "DonationDesertTile", phase.klass_name
    assert_equal 3, phase.remaining
  end

  test "settlement move source selection records from coordinate" do
    phase = TurnPhase.deserialize({ "type" => "paddock", "klass" => "PaddockTile" })

    result = phase.transition(
      TurnPhase::Events::SourceSelected.new(coordinate_key: "[5, 5]"),
      nil
    )

    assert_instance_of TurnPhase::SettlementMovePhase, result.next_phase
    assert_equal(
      { "type" => "paddock", "klass" => "PaddockTile", "from" => "[5, 5]" },
      result.next_phase.serialize
    )
  end

  test "deserializing a settlement move current_action returns settlement move phase" do
    phase = TurnPhase.deserialize({ "type" => "harbor", "klass" => "HarborTile", "from" => "[5, 5]" })

    assert_instance_of TurnPhase::SettlementMovePhase, phase
    assert_equal "harbor", phase.type
    assert_equal "HarborTile", phase.klass_name
    assert_equal "[5, 5]", phase.from
  end

  test "deserializing fort current_action returns fort phase" do
    phase = TurnPhase.deserialize({ "type" => "fort", "klass" => "FortTile", "fort_terrain" => "D" })

    assert_instance_of TurnPhase::FortPhase, phase
    assert_equal "fort", phase.type
    assert_equal "FortTile", phase.klass_name
    assert_equal "D", phase.fort_terrain
    assert_equal(
      { "type" => "fort", "klass" => "FortTile", "fort_terrain" => "D" },
      phase.serialize
    )
  end

  test "resettlement source selection records from coordinate" do
    phase = TurnPhase.deserialize({
      "type" => "resettlement",
      "klass" => "ResettlementTile",
      "budget" => 4,
      "moves" => 0
    })

    result = phase.transition(
      TurnPhase::Events::SourceSelected.new(coordinate_key: "[1, 2]"),
      nil
    )

    assert_instance_of TurnPhase::ResettlementPhase, result.next_phase
    assert_equal "[1, 2]", result.next_phase.from
    assert_equal 4, result.next_phase.budget
    assert_equal 0, result.next_phase.moves
  end

  test "deserializing resettlement current_action returns resettlement phase" do
    phase = TurnPhase.deserialize({
      "type" => "resettlement",
      "klass" => "ResettlementTile",
      "budget" => 3,
      "moves" => 1,
      "from" => "[5, 5]"
    })

    assert_instance_of TurnPhase::ResettlementPhase, phase
    assert_equal 3, phase.budget
    assert_equal 1, phase.moves
    assert_equal "[5, 5]", phase.from
  end

  test "meeple movement source selection records from coordinate" do
    phase = TurnPhase.deserialize({ "type" => "lighthouse", "klass" => "LighthouseTile" })

    result = phase.transition(
      TurnPhase::Events::SourceSelected.new(coordinate_key: "[0, 3]"),
      nil
    )

    assert_instance_of TurnPhase::MeepleMovementPhase, result.next_phase
    assert_equal(
      { "type" => "lighthouse", "klass" => "LighthouseTile", "budget" => 3, "moves" => 0, "from" => "[0, 3]" },
      result.next_phase.serialize
    )
  end

  test "targeted removal phase removes one pending order at a time" do
    phase = TurnPhase.deserialize({ "type" => "sword", "klass" => "SwordTile", "pending_orders" => [ 1, 2 ] })

    result = phase.consume_target(1)

    assert_instance_of TurnPhase::TargetedRemovalPhase, result.next_phase
    assert_equal({ "type" => "sword", "klass" => "SwordTile", "pending_orders" => [ 2 ] }, result.next_phase.serialize)
    assert_equal false, result.action_completed
  end

  test "deserializing barracks current_action returns meeple action phase" do
    phase = TurnPhase.deserialize({ "type" => "barracks", "klass" => "BarracksTile" })

    assert_instance_of TurnPhase::MeepleActionPhase, phase
    assert_equal({ "type" => "barracks", "klass" => "BarracksTile" }, phase.serialize)
  end

  test "deserializing city hall current_action returns city hall phase" do
    phase = TurnPhase.deserialize({ "type" => "cityhall", "klass" => "CityHallTile" })

    assert_instance_of TurnPhase::CityHallPhase, phase
    assert_equal({ "type" => "cityhall", "klass" => "CityHallTile" }, phase.serialize)
  end

  test "phases answer meeple_movement? and tile_action_endable? for themselves" do
    barracks = TurnPhase.deserialize({ "type" => "barracks", "klass" => "BarracksTile" })
    assert_equal false, barracks.meeple_movement?
    assert_equal false, barracks.tile_action_endable?

    movement = TurnPhase.deserialize({ "type" => "lighthouse", "klass" => "LighthouseTile", "budget" => 3, "moves" => 1 })
    assert_equal true, movement.meeple_movement?
    assert_equal true, movement.tile_action_endable?
    fresh_movement = TurnPhase.deserialize({ "type" => "lighthouse", "klass" => "LighthouseTile", "budget" => 3, "moves" => 0 })
    assert_equal false, fresh_movement.tile_action_endable?

    resettlement = TurnPhase.deserialize({ "type" => "resettlement", "klass" => "ResettlementTile", "budget" => 3, "moves" => 1 })
    assert_equal true, resettlement.tile_action_endable?
    assert_equal false, resettlement.meeple_movement?

    walled = TurnPhase.deserialize({ "type" => "quarry", "klass" => "QuarryTile", "walls_placed" => 1 })
    assert_equal true, walled.tile_action_endable?
  end

  test "move and resettlement phases accept source selection; others fall back" do
    paddock = TurnPhase.deserialize({ "type" => "paddock", "klass" => "PaddockTile" })
    resettlement = TurnPhase.deserialize({ "type" => "resettlement", "klass" => "ResettlementTile", "budget" => 3, "moves" => 0 })
    lighthouse = TurnPhase.deserialize({ "type" => "lighthouse", "klass" => "LighthouseTile" })
    barracks = TurnPhase.deserialize({ "type" => "barracks", "klass" => "BarracksTile" })

    assert_equal true, paddock.accepts_source_selection?
    assert_equal true, resettlement.accepts_source_selection?
    assert_equal true, lighthouse.accepts_source_selection?
    assert_equal false, barracks.accepts_source_selection?
  end

  test "phases identify their build kind" do
    mandatory = TurnPhase.deserialize({ "type" => "mandatory" })
    tile_build = TurnPhase.deserialize({ "type" => "oasis", "klass" => "OasisTile" })
    city_hall = TurnPhase.deserialize({ "type" => "cityhall", "klass" => "CityHallTile" })

    assert_equal true, mandatory.mandatory_build?
    assert_equal false, tile_build.mandatory_build?
    assert_equal false, mandatory.city_hall?
    assert_equal true, city_hall.city_hall?
  end

  test "with_outpost_active returns the same phase kind with outpost on" do
    mandatory = TurnPhase::MandatoryBuildPhase.new(chosen_terrain: "G", builds: [ [ 1, 1 ] ])
    activated = mandatory.with_outpost_active
    assert_instance_of TurnPhase::MandatoryBuildPhase, activated
    assert_equal true, activated.outpost_active?
    assert_equal "G", activated.chosen_terrain
    assert_equal [ [ 1, 1 ] ], activated.builds

    tile_build = TurnPhase::TileBuildPhase.new(action_type: "quarry", klass_name: "QuarryTile", walls_placed: 1)
    tile_activated = tile_build.with_outpost_active
    assert_instance_of TurnPhase::TileBuildPhase, tile_activated
    assert_equal true, tile_activated.outpost_active?
    assert_equal 1, tile_activated.walls_placed

    # A non-build phase falls back to a fresh outpost-active mandatory build.
    fallback = TurnPhase.deserialize({ "type" => "barracks", "klass" => "BarracksTile" }).with_outpost_active
    assert_instance_of TurnPhase::MandatoryBuildPhase, fallback
    assert_equal true, fallback.outpost_active?
  end

  test "with_chosen_terrain locks terrain and preserves phase kind" do
    mandatory = TurnPhase::MandatoryBuildPhase.new(builds: [ [ 0, 0 ] ], outpost_active: true)
    locked = mandatory.with_chosen_terrain("D")
    assert_instance_of TurnPhase::MandatoryBuildPhase, locked
    assert_equal "D", locked.chosen_terrain
    assert_equal [ [ 0, 0 ] ], locked.builds
    assert_equal true, locked.outpost_active?

    tile_build = TurnPhase::TileBuildPhase.new(action_type: "oasis", klass_name: "OasisTile", remaining: 2)
    tile_locked = tile_build.with_chosen_terrain("S")
    assert_instance_of TurnPhase::TileBuildPhase, tile_locked
    assert_equal "S", tile_locked.chosen_terrain
    assert_equal 2, tile_locked.remaining
  end

  test "a phase that owns none of the optional concepts exposes neutral defaults" do
    # The engine asks every current phase for these without a respond_to? guard
    # (e.g. turn_endable? reads outpost_active?, the move counter reads moves and
    # walls_placed), so a phase that lacks them must answer with the neutral value.
    phase = TurnPhase.deserialize({ "type" => "barracks", "klass" => "BarracksTile" })

    assert_nil phase.budget
    assert_nil phase.moves
    assert_nil phase.remaining
    assert_nil phase.walls_placed
    assert_nil phase.fort_terrain
    assert_nil phase.chosen_terrain
    assert_equal [], phase.pending_orders
    assert_equal false, phase.outpost_active?
  end
end
