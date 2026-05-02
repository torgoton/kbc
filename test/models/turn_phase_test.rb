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
      "vacated" => [],
      "moves" => 0
    })

    result = phase.transition(
      TurnPhase::Events::SourceSelected.new(coordinate_key: "[1, 2]"),
      nil
    )

    assert_instance_of TurnPhase::ResettlementPhase, result.next_phase
    assert_equal "[1, 2]", result.next_phase.from
    assert_equal 4, result.next_phase.budget
    assert_equal [], result.next_phase.vacated
    assert_equal 0, result.next_phase.moves
  end

  test "deserializing resettlement current_action returns resettlement phase" do
    phase = TurnPhase.deserialize({
      "type" => "resettlement",
      "klass" => "ResettlementTile",
      "budget" => 3,
      "vacated" => ["[2, 3]"],
      "moves" => 1,
      "from" => "[5, 5]"
    })

    assert_instance_of TurnPhase::ResettlementPhase, phase
    assert_equal 3, phase.budget
    assert_equal ["[2, 3]"], phase.vacated
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
      { "type" => "lighthouse", "klass" => "LighthouseTile", "from" => "[0, 3]" },
      result.next_phase.serialize
    )
  end

  test "targeted removal phase removes one pending order at a time" do
    phase = TurnPhase.deserialize({ "type" => "sword", "klass" => "SwordTile", "pending_orders" => [1, 2] })

    result = phase.consume_target(1)

    assert_instance_of TurnPhase::TargetedRemovalPhase, result.next_phase
    assert_equal({ "type" => "sword", "klass" => "SwordTile", "pending_orders" => [2] }, result.next_phase.serialize)
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
end
