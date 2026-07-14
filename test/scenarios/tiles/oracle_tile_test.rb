require "test_helper"

# OracleTile grants one extra settlement build on the same terrain as the
# player's played (hand) terrain card - adjacent to an existing settlement if
# possible, otherwise anywhere on that terrain - without consuming the
# mandatory build count. With multiple hand cards, any of their terrains is a
# valid destination.
class OracleTileTest < ActiveSupport::TestCase
  test "builds an extra settlement adjacent to an existing one on the played terrain" do
    scenario = GameScenario.new(hands: { 0 => "D" })
    target = scenario.empty_hexes("D", 1).first
    adjacent_spot = scenario.neighbors(target).find { |n| scenario.owner_at(n).nil? }
    scenario.place_settlement(0, at: adjacent_spot)
    scenario.give_tile(0, "OracleTile", from: [ 0, 0 ])

    scenario.activate_tile(:oracle)
    scenario.build_settlement(at: target)

    assert_equal 0, scenario.owner_at(target)
    assert_equal Game::SETTLEMENTS_PER_PLAYER - 1, scenario.settlements_remaining(0)
    assert_equal Game::MANDATORY_COUNT, scenario.mandatory_remaining
    assert_not_includes scenario.usable_tiles(0), "OracleTile"
  end

  test "builds anywhere on the played terrain when no settlement is adjacent to one" do
    scenario = GameScenario.new(hands: { 0 => "D" })
    scenario.give_tile(0, "OracleTile", from: [ 0, 0 ])
    target = scenario.empty_hexes("D", 1).first

    scenario.activate_tile(:oracle)
    scenario.build_settlement(at: target)

    assert_equal 0, scenario.owner_at(target)
    assert_equal Game::SETTLEMENTS_PER_PLAYER - 1, scenario.settlements_remaining(0)
  end

  test "restricts build destinations to the played terrain adjacent to the existing settlement" do
    scenario = GameScenario.new(hands: { 0 => "D" })
    terrain_hex = settlement_spot = nil
    scenario.empty_hexes("D", 40).each do |candidate|
      spot = scenario.neighbors(candidate).find do |n|
        scenario.owner_at(n).nil? && scenario.terrain_at(n) != "D"
      end
      if spot
        terrain_hex, settlement_spot = candidate, spot
        break
      end
    end
    raise "fixed board should offer a D hex with a non-D neighbor" unless settlement_spot
    scenario.place_settlement(0, at: settlement_spot)
    scenario.give_tile(0, "OracleTile", from: [ 0, 0 ])

    scenario.activate_tile(:oracle)
    destinations = scenario.buildable_cells

    assert_includes destinations, terrain_hex
    destinations.each do |dest|
      assert_includes scenario.neighbors(settlement_spot), dest,
        "#{dest.inspect} is not adjacent to the existing settlement at #{settlement_spot.inspect}"
      assert_equal "D", scenario.terrain_at(dest),
        "#{dest.inspect} is not D terrain"
    end
  end

  test "rejects a build on a different terrain than the played card" do
    scenario = GameScenario.new(hands: { 0 => "D" })
    scenario.give_tile(0, "OracleTile", from: [ 0, 0 ])
    wrong_hex = scenario.empty_hexes("C", 1).first

    scenario.activate_tile(:oracle)

    assert_raises(GameScenario::IllegalMove) { scenario.build_settlement(at: wrong_hex) }
  end

  test "with multiple hand terrains, destinations include hexes of either terrain" do
    scenario = GameScenario.new(hands: { 0 => %w[D G] })
    scenario.give_tile(0, "OracleTile", from: [ 0, 0 ])
    d_target = scenario.empty_hexes("D", 1).first
    g_target = scenario.empty_hexes("G", 1).first

    scenario.activate_tile(:oracle)
    destinations = scenario.buildable_cells

    assert_includes destinations, d_target
    assert_includes destinations, g_target
  end

  test "with multiple hand terrains, limits destinations to the already-locked played terrain" do
    scenario = GameScenario.new(hands: { 0 => %w[D G] })
    scenario.give_tile(0, "OracleTile", from: [ 0, 0 ])
    scenario.set_mandatory(1)

    build_spot = scenario.buildable_cells.find { |spot| scenario.terrain_at(spot) == "D" }
    scenario.build_settlement(at: build_spot)

    scenario.activate_tile(:oracle)
    destinations = scenario.buildable_cells

    assert destinations.any?
    destinations.each { |dest| assert_equal "D", scenario.terrain_at(dest) }
  end

  test "with multiple hand terrains, builds on whichever terrain the player chooses" do
    scenario = GameScenario.new(hands: { 0 => %w[D G] })
    scenario.give_tile(0, "OracleTile", from: [ 0, 0 ])
    g_target = scenario.empty_hexes("G", 1).first

    scenario.activate_tile(:oracle)
    scenario.build_settlement(at: g_target)

    assert_equal 0, scenario.owner_at(g_target)
    assert_equal Game::SETTLEMENTS_PER_PLAYER - 1, scenario.settlements_remaining(0)
    assert_not_includes scenario.usable_tiles(0), "OracleTile"
  end
end
