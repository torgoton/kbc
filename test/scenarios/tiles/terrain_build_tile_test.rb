require "test_helper"

# Parameterized build-bonus tile contract: Oasis, Farm, Garden, Forester's
# Lodge, and Monastery differ only in which terrain they build on, but share
# the same rule - activating the tile grants one extra settlement build
# constrained to that terrain (adjacent to an existing settlement if
# possible, otherwise anywhere on that terrain), without consuming the
# mandatory build count, and the tile becomes used afterward.
class TerrainBuildTileTest < ActiveSupport::TestCase
  TERRAIN_TILES = {
    oasis: { tile_klass: "OasisTile", action: :oasis, terrain: "D" },
    farm: { tile_klass: "FarmTile", action: :farm, terrain: "G" },
    garden: { tile_klass: "GardenTile", action: :garden, terrain: "F" },
    foresters_lodge: { tile_klass: "ForestersLodgeTile", action: :foresterslodge, terrain: "T" },
    monastery: { tile_klass: "MonasteryTile", action: :monastery, terrain: "C" }
  }.freeze

  TERRAIN_TILES.each do |_name, cfg|
    test "#{cfg[:tile_klass]} builds an extra settlement adjacent to an existing one on its terrain" do
      scenario = GameScenario.new
      target = scenario.empty_hexes(cfg[:terrain], 1).first
      adjacent_spot = scenario.neighbors(target).find { |n| scenario.owner_at(n).nil? }
      scenario.place_settlement(0, at: adjacent_spot)
      scenario.give_tile(0, cfg[:tile_klass], from: [ 0, 0 ])

      scenario.activate_tile(cfg[:action])
      scenario.build_settlement(at: target)

      assert_equal 0, scenario.owner_at(target)
      assert_equal Game::SETTLEMENTS_PER_PLAYER - 1, scenario.settlements_remaining(0)
      assert_equal Game::MANDATORY_COUNT, scenario.mandatory_remaining
      assert_not_includes scenario.usable_tiles(0), cfg[:tile_klass]
    end

    test "#{cfg[:tile_klass]} builds anywhere on its terrain when no settlement is adjacent to one" do
      scenario = GameScenario.new
      scenario.give_tile(0, cfg[:tile_klass], from: [ 0, 0 ])
      target = scenario.empty_hexes(cfg[:terrain], 1).first

      scenario.activate_tile(cfg[:action])
      scenario.build_settlement(at: target)

      assert_equal 0, scenario.owner_at(target)
      assert_equal Game::SETTLEMENTS_PER_PLAYER - 1, scenario.settlements_remaining(0)
    end

    test "#{cfg[:tile_klass]} restricts build destinations to its terrain adjacent to the existing settlement" do
      scenario = GameScenario.new
      terrain_hex = settlement_spot = nil
      scenario.empty_hexes(cfg[:terrain], 40).each do |candidate|
        spot = scenario.neighbors(candidate).find do |n|
          scenario.owner_at(n).nil? && scenario.terrain_at(n) != cfg[:terrain]
        end
        if spot
          terrain_hex, settlement_spot = candidate, spot
          break
        end
      end
      raise "fixed board should offer a #{cfg[:terrain]} hex with a non-#{cfg[:terrain]} neighbor" unless settlement_spot
      scenario.place_settlement(0, at: settlement_spot)
      scenario.give_tile(0, cfg[:tile_klass], from: [ 0, 0 ])

      scenario.activate_tile(cfg[:action])
      destinations = scenario.buildable_cells

      assert_includes destinations, terrain_hex
      destinations.each do |dest|
        assert_includes scenario.neighbors(settlement_spot), dest,
          "#{dest.inspect} is not adjacent to the existing settlement at #{settlement_spot.inspect}"
        assert_equal cfg[:terrain], scenario.terrain_at(dest),
          "#{dest.inspect} is not #{cfg[:terrain]} terrain"
      end
    end

    test "#{cfg[:tile_klass]} rejects a build on a different terrain" do
      scenario = GameScenario.new
      scenario.give_tile(0, cfg[:tile_klass], from: [ 0, 0 ])
      wrong_terrain = (Tiles::Tile::BUILDABLE_TERRAIN - [ cfg[:terrain] ]).first
      wrong_hex = scenario.empty_hexes(wrong_terrain, 1).first

      scenario.activate_tile(cfg[:action])

      assert_raises(GameScenario::IllegalMove) { scenario.build_settlement(at: wrong_hex) }
    end
  end
end
