require "test_helper"

class ForfeitScenarioTest < ActiveSupport::TestCase
  # When a player holds two interchangeable copies of a location tile and a move
  # leaves only one source hex adjacent to a settlement, exactly one copy is
  # forfeited. The rule is prefer-used: keep the unused copy, forfeit the used
  # one (confirmed with the game owner 2026-06-12), so the player retains a
  # usable tile rather than losing it to the accident of which copy was spent.
  test "forfeit drops the used copy and keeps the unused one when sources are interchangeable" do
    scenario = GameScenario.new(hands: { 0 => "G", 1 => "D" })

    # Two grass hexes whose neighbourhoods don't overlap, so each settlement's
    # adjacency is independent.
    grass = scenario.empty_hexes("G", 200)
    stationary = grass.first
    mover = grass.find do |g|
      g != stationary &&
        (scenario.neighbors(g) & (scenario.neighbors(stationary) + [ stationary ])).empty? &&
        scenario.neighbors(g).count { |n| scenario.terrain_at(n) == "G" && scenario.owner_at(n).nil? } >= 2
    end
    raise "fixed board should offer two independent grass settlements" unless mover

    # Destination one grass step from the mover, plus a source hex Y adjacent to
    # the mover but NOT to the destination (so the move breaks Y's adjacency).
    movable_neighbors = scenario.neighbors(mover).select do |n|
      scenario.terrain_at(n) == "G" && scenario.owner_at(n).nil?
    end
    dest = movable_neighbors.first
    y_source = scenario.neighbors(mover).find do |n|
      n != dest && !scenario.neighbors(dest).include?(n) &&
        !scenario.neighbors(stationary).include?(n) && n != stationary
    end
    x_source = scenario.neighbors(stationary).first
    raise "could not place independent tile sources" unless y_source && x_source

    scenario.place_settlement(0, at: stationary)
    scenario.place_settlement(0, at: mover)
    scenario.give_tile(0, "FarmTile", from: x_source, used: true)   # source stays adjacent
    scenario.give_tile(0, "FarmTile", from: y_source, used: false)  # source goes non-adjacent
    scenario.give_tile(0, "ResettlementTile", from: [ 0, 0 ])

    scenario.activate_tile(:resettlement)
    scenario.select_settlement(at: mover)
    scenario.move_step(to: dest)

    farms = scenario.held_tiles(0, klass: "FarmTile")
    assert_equal 1, farms.size, "exactly one FarmTile should be forfeited"
    assert_not farms.first["used"], "the surviving FarmTile should be the unused copy (prefer-used)"
  end
end
