require "test_helper"

# Parameterized stepped meeple-movement contract: wagon and ship differ only
# in which terrain they can travel on and how they're placed/activated, but
# share the same rules - relocate one hex per step (vacating the source),
# pick up location tiles en route, forfeit non-Nomad tiles that lose
# adjacency, and are limited to a 3-step budget per activation.
class MeepleMovementContractTest < ActiveSupport::TestCase
  MOVERS = {
    wagon: {
      tile_klass: "WagonTile",
      action: :wagon,
      piece_name: "wagon",
      start_terrain: "G",
      place: ->(scenario, player, at:) { scenario.place_wagon(player, at: at) },
      suitable_terrain?: ->(scenario, hex) { Tiles::WagonTile::SUITABLE_TERRAIN.include?(scenario.terrain_at(hex)) }
    },
    lighthouse: {
      tile_klass: "LighthouseTile",
      action: :lighthouse,
      piece_name: "ship",
      start_terrain: "W",
      place: ->(scenario, player, at:) { scenario.place_ship(player, at: at) },
      suitable_terrain?: ->(scenario, hex) { scenario.terrain_at(hex) == "W" }
    }
  }.freeze

  MOVERS.each do |_mover, cfg|
    test "#{cfg[:piece_name]} relocates one hex per step, vacating the source" do
      scenario = GameScenario.new(hands: { 0 => "G", 1 => "D" })
      scenario.give_tile(0, cfg[:tile_klass], from: [ 0, 0 ])
      start = scenario.empty_hexes(cfg[:start_terrain], 1).first
      cfg[:place].call(scenario, 0, at: start)
      step = scenario.neighbors(start).find do |n|
        cfg[:suitable_terrain?].call(scenario, n) && scenario.owner_at(n).nil?
      end
      raise "fixed board should offer an adjacent suitable hex" unless step

      scenario.activate_tile(cfg[:action])
      scenario.select_meeple(at: start)
      scenario.move_meeple_step(to: step)

      assert_equal 0, scenario.owner_at(step)
      assert_nil scenario.owner_at(start)
    end

    test "#{cfg[:piece_name]} picks up a location tile when it steps onto a hex adjacent to it" do
      scenario = GameScenario.new(hands: { 0 => "G", 1 => "D" })
      scenario.give_tile(0, cfg[:tile_klass], from: [ 0, 0 ])
      start = scenario.empty_hexes(cfg[:start_terrain], 1).first
      cfg[:place].call(scenario, 0, at: start)
      step = scenario.neighbors(start).find do |n|
        cfg[:suitable_terrain?].call(scenario, n) && scenario.owner_at(n).nil?
      end
      raise "fixed board should offer an adjacent suitable hex" unless step
      tile_hex = scenario.neighbors(step).find { |n| n != start && scenario.owner_at(n).nil? }
      raise "fixed board should offer a neighbor for a location tile" unless tile_hex
      scenario.place_tile("OasisTile", at: tile_hex, qty: 2)

      scenario.activate_tile(cfg[:action])
      scenario.select_meeple(at: start)
      scenario.move_meeple_step(to: step)

      assert scenario.holds_tile?(0, klass: "OasisTile", from: tile_hex)
      assert_equal 1, scenario.tile_qty(tile_hex)
    end

    test "#{cfg[:piece_name]} move forfeits a non-Nomad tile that loses adjacency, but keeps a Nomad tile" do
      scenario = GameScenario.new(hands: { 0 => "G", 1 => "D" })
      scenario.give_tile(0, cfg[:tile_klass], from: [ 0, 0 ])
      start = scenario.empty_hexes(cfg[:start_terrain], 1).first
      cfg[:place].call(scenario, 0, at: start)
      step = scenario.neighbors(start).find do |n|
        cfg[:suitable_terrain?].call(scenario, n) && scenario.owner_at(n).nil?
      end
      raise "fixed board should offer an adjacent suitable hex" unless step
      lost_adjacency = scenario.neighbors(start) - scenario.neighbors(step) - [ step ]
      raise "fixed board should offer hexes that lose adjacency after the move" if lost_adjacency.size < 2
      farm_source, outpost_source = lost_adjacency.first(2)
      scenario.give_tile(0, "FarmTile", from: farm_source)
      scenario.give_tile(0, "OutpostTile", from: outpost_source)

      scenario.activate_tile(cfg[:action])
      scenario.select_meeple(at: start)
      scenario.move_meeple_step(to: step)

      assert_not scenario.holds_tile?(0, klass: "FarmTile", from: farm_source),
        "FarmTile should be forfeited once its source loses all adjacency"
      assert scenario.holds_tile?(0, klass: "OutpostTile", from: outpost_source),
        "Nomad tiles are never forfeited, regardless of adjacency"
    end

    test "#{cfg[:piece_name]} can move up to its budget of 3 steps, then no further" do
      scenario = GameScenario.new(hands: { 0 => "G", 1 => "D" })
      scenario.give_tile(0, cfg[:tile_klass], from: [ 0, 0 ])
      start = scenario.empty_hexes(cfg[:start_terrain], 1).first
      cfg[:place].call(scenario, 0, at: start)

      path = find_step_path(scenario, cfg, [ start ], 3)
      raise "fixed board should offer a 3-step suitable path" unless path

      scenario.activate_tile(cfg[:action])
      scenario.select_meeple(at: start)
      path.each { |hex| scenario.move_meeple_step(to: hex) }

      assert_equal 0, scenario.owner_at(path.last)
      assert_nil scenario.owner_at(start)

      visited = [ start ] + path
      extra = scenario.neighbors(path.last).find do |n|
        !visited.include?(n) && cfg[:suitable_terrain?].call(scenario, n) && scenario.owner_at(n).nil?
      end
      raise "fixed board should offer a 4th candidate hex" unless extra

      assert_raises(GameScenario::IllegalMove) { scenario.move_meeple_step(to: extra) }
    end
  end

  # Backtracking search for a length-`steps` path of suitable, empty hexes
  # starting from `visited.last` (not revisiting any hex in `visited`).
  def find_step_path(scenario, cfg, visited, steps)
    return [] if steps.zero?

    scenario.neighbors(visited.last).each do |n|
      next if visited.include?(n)
      next unless cfg[:suitable_terrain?].call(scenario, n) && scenario.owner_at(n).nil?

      rest = find_step_path(scenario, cfg, visited + [ n ], steps - 1)
      return [ n ] + rest if rest
    end

    nil
  end
end
