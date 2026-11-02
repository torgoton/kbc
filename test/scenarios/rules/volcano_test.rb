require "test_helper"

# Volcano decree: after the Silo round and before scoring, each player in turn order removes a third
# (rounded up) of their pieces in the volcano's board section. City Hall hexes count but stay.
class VolcanoScenarioTest < ActiveSupport::TestCase
  VOLCANO = [ 0, 0 ].freeze # board section 0: rows 0-9, cols 0-9

  def scenario(boards: GameScenario::DEFAULT_BOARDS)
    GameScenario.new(boards:).tap do |s|
      s.game.update!(decree: { "name" => "volcano", "hex" => VOLCANO })
    end
  end

  def place(scenario, player, *cells)
    cells.each { |cell| scenario.place_settlement(player, at: cell) }
  end

  test "a player removes a third of their pieces in the section, rounded up, then the next player does" do
    s = scenario
    place(s, 0, [ 1, 1 ], [ 1, 2 ], [ 1, 3 ], [ 1, 4 ])   # 4 -> remove 2
    place(s, 0, [ 15, 15 ])                                # another section: not counted
    place(s, 1, [ 2, 1 ])                                  # 1 -> remove 1

    s.finish_final_round

    assert_equal "playing", s.state
    assert_equal({ "type" => "volcano", "remaining" => 2 }, s.phase)
    assert_equal 0, s.current_order
    assert_not s.turn_endable?

    s.build_settlement(at: [ 1, 1 ])
    s.build_settlement(at: [ 1, 2 ])
    assert_nil s.owner_at([ 1, 1 ])
    assert_equal 0, s.owner_at([ 1, 3 ])
    assert s.turn_endable?

    s.end_turn
    assert_equal 1, s.current_order
    assert_equal({ "type" => "volcano", "remaining" => 1 }, s.phase)
    s.build_settlement(at: [ 2, 1 ])
    s.end_turn

    assert_equal "completed", s.state
    assert_equal 0, s.owner_at([ 15, 15 ])
  end

  test "only the player's own pieces in the section can be removed, and only while some are due" do
    s = scenario
    place(s, 0, [ 1, 1 ])
    place(s, 1, [ 2, 2 ])
    s.finish_final_round

    assert_raises(GameScenario::IllegalMove) { s.build_settlement(at: [ 2, 2 ]) } # an opponent's
    s.build_settlement(at: [ 1, 1 ])
    assert_raises(GameScenario::IllegalMove) { s.build_settlement(at: [ 1, 1 ]) } # nothing left to remove
  end

  test "City Hall hexes count towards the third but cannot be removed" do
    s = scenario
    s.place_city_hall_hex(0, at: [ 1, 1 ])
    s.place_city_hall_hex(0, at: [ 1, 2 ])
    s.place_city_hall_hex(0, at: [ 2, 1 ])
    place(s, 0, [ 4, 4 ], [ 4, 5 ], [ 4, 6 ])   # 6 pieces: remove 2, from the 3 removable ones

    s.finish_final_round

    assert_equal({ "type" => "volcano", "remaining" => 2 }, s.phase)
    assert_raises(GameScenario::IllegalMove) { s.build_settlement(at: [ 1, 1 ]) }
    s.build_settlement(at: [ 4, 4 ])
    assert_equal 0, s.owner_at([ 1, 1 ])
  end

  test "a player with only City Hall hexes in the section has nothing to remove" do
    s = scenario
    s.place_city_hall_hex(0, at: [ 1, 1 ])

    s.finish_final_round

    assert_equal "completed", s.state
  end

  test "a player with only City Hall hexes in the section is skipped for the next player" do
    s = scenario
    s.place_city_hall_hex(0, at: [ 1, 1 ])
    place(s, 1, [ 2, 2 ])

    s.finish_final_round

    assert_equal 1, s.current_order
    assert_equal({ "type" => "volcano", "remaining" => 1 }, s.phase)
  end

  test "the game ends as before when nobody has pieces in the volcano's section" do
    s = scenario
    place(s, 0, [ 15, 15 ])

    s.finish_final_round

    assert_equal "completed", s.state
  end

  test "a removal can be undone" do
    s = scenario
    place(s, 0, [ 1, 1 ])
    s.finish_final_round

    s.build_settlement(at: [ 1, 1 ])
    s.undo

    assert_equal 0, s.owner_at([ 1, 1 ])
    assert_equal({ "type" => "volcano", "remaining" => 1 }, s.phase)
  end

  test "the Volcano round comes after the Silo round" do
    s = scenario(boards: GameScenario::HARVEST_BOARDS)
    place(s, 0, [ 7, 3 ]) # next to board 20's Silo, in section 0

    s.finish_final_round
    assert_equal "silo", s.phase["type"]

    s.silo_choice("skip")
    s.end_turn

    assert_equal({ "type" => "volcano", "remaining" => 1 }, s.phase)
  end
end
