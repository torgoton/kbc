require "test_helper"

# Mayors: whenever a build or move gives you 4+ settlements on a horizontal row nobody has
# marked yet, a settlement from your supply becomes that row's marker. Each marker scores 4.
class MayorsScenarioTest < ActiveSupport::TestCase
  # Four neighbouring empty hexes of one terrain in a single row: the first three are
  # pre-built for player 0, the fourth is built (or moved) by the test.
  Setup = Struct.new(:scenario, :row, :owned, :last)

  def setup_row(goals: [ "mayors" ], owned: 3)
    %w[G C D F T].each do |terrain|
      s = GameScenario.new(goals:, hands: { 0 => terrain, 1 => terrain })
      spots = s.empty_hexes(terrain, 400)
      spots.each do |a|
        run = [ a ]
        owned.times { run << [ a[0], run.last[1] + 1 ] }
        next unless run.all? { |h| spots.include?(h) }
        run[0...owned].each { |h| s.place_settlement(0, at: h) }
        return Setup.new(s, a[0], run[0...owned], run[owned])
      end
    end
    raise "fixed boards should have a run of 4 hexes in a row"
  end

  test "the 4th settlement in a row claims it with a marker from the supply" do
    t = setup_row
    t.scenario.build_settlement(at: t.last)

    assert_equal [ t.row ], t.scenario.mayor_rows(0)
    assert_equal 38, t.scenario.settlements_remaining(0)
  end

  test "each marker scores 4" do
    t = setup_row
    t.scenario.build_settlement(at: t.last)

    assert_equal 4, t.scenario.score_for("mayors", 0)
  end

  test "logs the claim" do
    t = setup_row
    t.scenario.build_settlement(at: t.last)

    assert_includes t.scenario.moves.map(&:message), "scenario-#{t.scenario.game.id}-p0 claims Mayor of row #{t.row}"
  end

  test "no claim without the Mayors goal" do
    t = setup_row(goals: [])
    t.scenario.build_settlement(at: t.last)

    assert_empty t.scenario.mayor_rows(0)
    assert_equal 39, t.scenario.settlements_remaining(0)
  end

  test "3 settlements are not enough" do
    t = setup_row(owned: 2)
    t.scenario.build_settlement(at: t.last)

    assert_empty t.scenario.mayor_rows(0)
  end

  test "a row already marked by anyone is not claimed again" do
    t = setup_row
    t.scenario.give_mayor_row(1, t.row)
    t.scenario.build_settlement(at: t.last)

    assert_empty t.scenario.mayor_rows(0)
    assert_equal 39, t.scenario.settlements_remaining(0)
  end

  test "a row you already marked is not claimed twice" do
    t = setup_row
    t.scenario.give_mayor_row(0, t.row)
    t.scenario.build_settlement(at: t.last)

    assert_equal [ t.row ], t.scenario.mayor_rows(0)
  end

  test "no claim when the supply is empty" do
    t = setup_row
    t.scenario.set_settlements(0, 1)
    t.scenario.build_settlement(at: t.last)

    assert_empty t.scenario.mayor_rows(0)
    assert_equal 0, t.scenario.settlements_remaining(0)
  end

  test "a claim that empties the supply triggers the game end" do
    t = setup_row
    t.scenario.set_settlements(0, 2)
    t.scenario.build_settlement(at: t.last)

    assert_equal [ t.row ], t.scenario.mayor_rows(0)
    assert_equal 1, t.scenario.end_trigger_count
  end

  test "undoing the build takes the marker back" do
    t = setup_row
    assert_undo_round_trip(t.scenario) { t.scenario.build_settlement(at: t.last) }
  end

  test "moving a settlement into the row claims it" do
    t = setup_row
    s = t.scenario
    from = [ t.row + 2, t.last[1] - 1 ] # Paddock jumps exactly 2 hexes (offset rows shift the column)
    s.place_settlement(0, at: from)
    s.give_tile(0, "PaddockTile", from: [ 0, 0 ])
    s.activate_tile(:paddock)
    s.select_settlement(at: from)
    s.move_step(to: t.last)

    assert_equal [ t.row ], s.mayor_rows(0)
  end

  test "placing a warrior counts as a settlement in the row" do
    t = setup_row
    s = t.scenario
    s.give_warriors(0, 1)
    s.give_tile(0, "BarracksTile", from: [ 0, 0 ])
    s.activate_tile(:barracks)
    s.move_meeple_step(to: t.last)

    assert_equal [ t.row ], s.mayor_rows(0)
  end

  test "moving a wagon into the row claims it" do
    t = setup_row
    s = t.scenario
    wagon = s.neighbors(t.last).find { |h| h[0] != t.row && s.owner_at(h).nil? }
    s.place_wagon(0, at: wagon)
    s.give_tile(0, "WagonTile", from: [ 0, 0 ])
    s.activate_tile(:wagon)
    s.select_meeple(at: wagon)
    s.move_meeple_step(to: t.last)

    assert_equal [ t.row ], s.mayor_rows(0)
  end

  test "a City Hall's 3 hexes in a row count" do
    s = GameScenario.new(goals: [ "mayors" ], hands: { 0 => "G", 1 => "G" })
    s.place_settlement(0, at: [ 4, 7 ])
    s.give_city_halls(0, 1)
    s.give_tile(0, "CityHallTile", from: [ 0, 0 ])
    s.activate_tile(:cityhall)
    s.place_city_hall(at: [ 4, 9 ])

    assert_equal [ 4 ], s.mayor_rows(0)
  end
end
