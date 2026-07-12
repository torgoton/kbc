require "test_helper"

class TilePickupScenarioTest < ActiveSupport::TestCase
  test "building adjacent to a location hex with remaining tiles picks one up" do
    scenario = GameScenario.new(hands: { 0 => "G", 1 => "D" })
    spot = scenario.empty_hexes("G", 1).first
    tile_spot = scenario.neighbors(spot).first
    scenario.place_tile("OasisTile", at: tile_spot, qty: 2)

    scenario.build_settlement(at: spot)

    assert scenario.holds_tile?(0, klass: "OasisTile", from: tile_spot)
    assert_equal 1, scenario.tile_qty(tile_spot)
  end

  test "building away from any location hex picks up nothing" do
    scenario = GameScenario.new(hands: { 0 => "G", 1 => "D" })
    spot = scenario.empty_hexes("G", 1).first

    scenario.build_settlement(at: spot)

    assert_not scenario.holds_tile?(0, klass: "OasisTile")
  end

  test "picking up a meeple-granting location tile grants a meeple, and undo revokes it" do
    scenario = GameScenario.new(hands: { 0 => "G", 1 => "D" })
    spot = scenario.empty_hexes("G", 1).first
    tile_hex = scenario.neighbors(spot).find { |n| scenario.owner_at(n).nil? }
    scenario.place_tile("BarracksTile", at: tile_hex, qty: 2) # BarracksTile grants a warrior
    warriors_before = scenario.warriors_remaining(0)

    # The round-trip proves undo revokes the granted warrior (the pre-build
    # snapshot has the smaller supply); its post state proves the grant.
    assert_undo_round_trip(scenario) { scenario.build_settlement(at: spot) }

    assert scenario.holds_tile?(0, klass: "BarracksTile", from: tile_hex)
    assert_operator scenario.warriors_remaining(0), :>, warriors_before
  end

  test "a player cannot take a second tile from a location they have already taken from" do
    scenario = GameScenario.new(hands: { 0 => "G", 1 => "D" })

    # Two grass build spots adjacent to the same location hex, the second also
    # adjacent to the first (so the second mandatory build is legal).
    spot1 = tile_hex = spot2 = nil
    scenario.empty_hexes("G", 400).each do |s1|
      scenario.neighbors(s1).each do |th|
        next unless scenario.owner_at(th).nil?
        s2 = scenario.neighbors(th).find do |n|
          n != s1 && scenario.neighbors(s1).include?(n) &&
            scenario.terrain_at(n) == "G" && scenario.owner_at(n).nil?
        end
        spot1, tile_hex, spot2 = s1, th, s2 if s2
        break if s2
      end
      break if spot2
    end
    raise "fixed board should offer two adjacent grass spots sharing a location neighbor" unless spot2
    scenario.place_tile("OasisTile", at: tile_hex, qty: 2)

    scenario.build_settlement(at: spot1) # seizes one tile from the location
    assert_equal 1, scenario.tile_qty(tile_hex)

    scenario.build_settlement(at: spot2) # adjacent to the same location, already seized

    assert_equal 1, scenario.tile_qty(tile_hex), "no second tile is taken from a seized location"
    assert_equal 1, scenario.held_tiles(0, klass: "OasisTile").size
  end

  test "cannot re-seize a location after moving away and forfeiting the tile taken from it" do
    # Fixed-board geometry (see paddock_tile_test for the jump rule):
    #   SEIZE    - grass hex adjacent to the location, the only settlement near it
    #   AWAY     - the 2-hex paddock jump from SEIZE, not adjacent to the location
    #              (jumping here breaks adjacency and forfeits the picked-up tile)
    #   REBUILD  - grass hex adjacent to BOTH the location and AWAY (so the second
    #              build is legal once the settlement sits on AWAY)
    location = [ 0, 8 ].freeze
    seize    = [ 0, 9 ].freeze
    away     = [ 2, 8 ].freeze
    rebuild  = [ 1, 8 ].freeze
    scenario = GameScenario.new(hands: { 0 => "G", 1 => "D" })
    scenario.place_tile("OasisTile", at: location, qty: 2)
    scenario.give_tile(0, "PaddockTile", from: [ 0, 0 ])

    scenario.build_settlement(at: seize) # picks up an OasisTile from the location
    assert scenario.holds_tile?(0, klass: "OasisTile", from: location)

    scenario.activate_tile(:paddock) # jump the settlement off the location, forfeiting the tile
    scenario.select_settlement(at: seize)
    scenario.move_step(to: away)
    assert_equal 0, scenario.owner_at(away)
    assert_empty scenario.held_tiles(0, klass: "OasisTile"), "moving away forfeits the tile"

    scenario.build_settlement(at: rebuild) # build next to the same location again

    assert_empty scenario.held_tiles(0, klass: "OasisTile"),
      "a location already taken from yields nothing on a later build, even after the tile was lost"
  end
end
