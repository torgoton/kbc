require "test_helper"

# SwordTile lets the player remove one settlement from each opponent that has
# at least one on the board, returning each to its owner's supply.
class SwordTileTest < ActiveSupport::TestCase
  OPPONENT_SETTLEMENT = [ 10, 10 ].freeze

  test "removes one settlement from the targeted opponent and returns it to their supply" do
    scenario = GameScenario.new
    scenario.place_settlement(1, at: OPPONENT_SETTLEMENT)
    scenario.give_tile(0, "SwordTile", from: [ 0, 0 ])

    scenario.activate_tile(:sword)

    # The opponent's settlement is highlighted as a removal target (dispatched
    # polymorphically via sword_tile?).
    assert_includes scenario.buildable_cells, OPPONENT_SETTLEMENT

    before_supply = scenario.settlements_remaining(1)
    scenario.remove_settlement(at: OPPONENT_SETTLEMENT)

    assert_nil scenario.owner_at(OPPONENT_SETTLEMENT)
    assert_equal before_supply + 1, scenario.settlements_remaining(1)
    assert_equal Game::MANDATORY_COUNT, scenario.mandatory_remaining

    # The removal completes the action: the tile is marked used and the phase
    # resets to mandatory build.
    assert_not_includes scenario.usable_tiles(0), "SwordTile"
  end

  test "cannot be activated when no opponent has a settlement on the board" do
    scenario = GameScenario.new
    scenario.give_tile(0, "SwordTile", from: [ 0, 0 ])

    assert_raises(GameScenario::IllegalMove) { scenario.activate_tile(:sword) }
  end

  test "removing an opponent's only adjacency to a location tile forfeits that tile" do
    scenario = GameScenario.new
    tile_location = scenario.neighbors(OPPONENT_SETTLEMENT).first
    scenario.place_settlement(1, at: OPPONENT_SETTLEMENT) # opponent's only adjacency to the location
    scenario.place_tile("PaddockTile", at: tile_location, qty: 2)
    scenario.give_tile(1, "PaddockTile", from: tile_location)
    scenario.give_tile(0, "SwordTile", from: [ 0, 0 ])

    scenario.activate_tile(:sword)
    scenario.remove_settlement(at: OPPONENT_SETTLEMENT)

    assert_empty scenario.held_tiles(1, klass: "PaddockTile")
  end

  test "removing a warrior returns it to the warrior supply, not the settlement supply" do
    scenario = GameScenario.new
    warrior_hex = scenario.empty_hexes("G", 1).first
    scenario.give_warriors(1, 1)
    scenario.place_warrior(1, at: warrior_hex)
    scenario.place_settlement(1, at: OPPONENT_SETTLEMENT) # so the Sword can be activated
    scenario.give_tile(0, "SwordTile", from: [ 0, 0 ])
    scenario.activate_tile(:sword)
    warriors_before = scenario.warriors_remaining(1)
    settlements_before = scenario.settlements_remaining(1)

    scenario.remove_settlement(at: warrior_hex)

    assert_equal warriors_before + 1, scenario.warriors_remaining(1)
    assert_equal settlements_before, scenario.settlements_remaining(1)
  end

  test "removing a settlement round-trips through undo" do
    scenario = GameScenario.new
    scenario.place_settlement(1, at: OPPONENT_SETTLEMENT)
    scenario.give_tile(0, "SwordTile", from: [ 0, 0 ])
    scenario.activate_tile(:sword)

    assert_undo_round_trip(scenario) { scenario.remove_settlement(at: OPPONENT_SETTLEMENT) }
  end

  test "removing a warrior round-trips through undo (restored as a warrior, not a settlement)" do
    scenario = GameScenario.new
    warrior_hex = scenario.empty_hexes("G", 1).first
    scenario.give_warriors(1, 1)
    scenario.place_warrior(1, at: warrior_hex)
    scenario.place_settlement(1, at: OPPONENT_SETTLEMENT)
    scenario.give_tile(0, "SwordTile", from: [ 0, 0 ])
    scenario.activate_tile(:sword)

    # The round-trip's snapshot equality proves the warrior (not a settlement)
    # is restored: a settlement would make the pre/post snapshots differ.
    assert_undo_round_trip(scenario) { scenario.remove_settlement(at: warrior_hex) }
  end
end
