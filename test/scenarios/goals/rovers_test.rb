require "test_helper"

# Rovers is scored at build time, once per board section per turn: 1 point for each section
# you build in during your own turn. Movement, Canoe reactions and Silo builds don't count.
class RoversScenarioTest < ActiveSupport::TestCase
  def section(cell) = cell[0] / 10 * 2 + cell[1] / 10

  def scenario
    GameScenario.new(goals: [ "rovers" ], hands: { 0 => "C", 1 => "C" })
  end

  # Two adjacent empty Canyon hexes, in the same board section or in different ones.
  def canyon_pair(scenario, same_section:)
    spots = scenario.empty_hexes("C", 400)
    spots.each do |a|
      scenario.neighbors(a).each do |b|
        return [ a, b ] if spots.include?(b) && (section(a) == section(b)) == same_section
      end
    end
    raise "fixed boards should have such a pair of Canyon hexes"
  end

  test "the first build in a section scores 1" do
    s = scenario
    s.build_settlement(at: s.empty_hexes("C", 1).first)

    assert_equal 1, s.score_for("rovers", 0)
  end

  test "more builds in the same section that turn score nothing" do
    s = scenario
    a, b = canyon_pair(s, same_section: true)

    s.build_settlement(at: a)
    s.build_settlement(at: b)

    assert_equal 1, s.score_for("rovers", 0)
  end

  test "building in a second section scores another point" do
    s = scenario
    a, b = canyon_pair(s, same_section: false)

    s.build_settlement(at: a)
    s.build_settlement(at: b)

    assert_equal 2, s.score_for("rovers", 0)
  end

  test "undoing a build takes its point back and lets the section score again" do
    s = scenario
    spot = s.empty_hexes("C", 1).first
    s.build_settlement(at: spot)
    s.undo
    assert_equal 0, s.score_for("rovers", 0)

    s.build_settlement(at: spot)
    assert_equal 1, s.score_for("rovers", 0)
  end

  test "each turn scores its sections afresh" do
    s = scenario
    spot = s.empty_hexes("C", 1).first
    s.set_mandatory(1)
    s.build_settlement(at: spot)
    s.end_turn
    s.set_mandatory(0)
    s.end_turn # player 1 passes

    s.build_settlement(at: s.buildable_cells.first)

    assert_equal 2, s.score_for("rovers", 0)
  end

  test "moving a settlement does not score" do
    s = scenario
    s.place_settlement(0, at: s.empty_hexes("C", 1).first)
    s.give_tile(0, "PaddockTile", from: [ 0, 0 ])
    s.activate_tile(:paddock)
    s.select_settlement(at: s.empty_hexes("C", 1).first.then { |_| s.buildable_cells.first })
    s.move_step(to: s.buildable_cells.first)

    assert_equal 0, s.score_for("rovers", 0)
  end

  test "placing a warrior counts as a build" do
    s = scenario
    s.place_settlement(0, at: s.empty_hexes("C", 1).first)
    s.give_warriors(0, 1)
    s.give_tile(0, "BarracksTile", from: [ 0, 0 ])
    s.activate_tile(:barracks)

    s.move_meeple_step(to: s.buildable_cells.first)

    assert_equal 1, s.score_for("rovers", 0)
  end

  test "moving a wagon does not score" do
    s = scenario
    wagon = s.empty_hexes("C", 1).first
    s.place_wagon(0, at: wagon)
    s.give_tile(0, "WagonTile", from: [ 0, 0 ])
    s.activate_tile(:wagon)
    s.select_meeple(at: wagon)
    s.move_meeple_step(to: s.buildable_cells.first)

    assert_equal 0, s.score_for("rovers", 0)
  end

  test "a City Hall scores for each section its 7 hexes cover" do
    # Centred on [4, 9], the cluster spans the top-left and top-right sections; [4, 7] is beside it.
    s = scenario
    s.place_settlement(0, at: [ 4, 7 ])
    s.give_city_halls(0, 1)
    s.give_tile(0, "CityHallTile", from: [ 0, 0 ])
    s.activate_tile(:cityhall)

    s.place_city_hall(at: [ 4, 9 ])

    assert_equal 2, s.score_for("rovers", 0)
  end

  test "a Silo build does not score" do
    s = GameScenario.new(goals: [ "rovers" ], boards: GameScenario::HARVEST_BOARDS)
    s.place_settlement(0, at: [ 7, 3 ])
    s.finish_final_round
    s.silo_choice("build")

    s.build_settlement(at: s.buildable_cells.first)

    assert_equal 0, s.score_for("rovers", 0)
  end
end
