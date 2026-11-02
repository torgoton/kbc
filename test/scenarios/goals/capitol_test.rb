require "test_helper"

# Capitol decree: 1 point per settlement 1 or 2 hexes from a Capitol (once, however many are near).
class CapitolScenarioTest < ActiveSupport::TestCase
  def capitol_scenario
    scenario = GameScenario.new(goals: [ "capitol" ])
    game = scenario.game
    game.instantiate
    capitol = game.board.silver_hexes_of("Castle").first
    game.update!(decree: { "name" => "capitol", "hexes" => [ capitol ] })
    game.board = nil
    [ scenario, capitol ]
  end

  def free_hexes_at(scenario, capitol, distance)
    BoardState::MAIN_CELLS.select do |cell|
      BoardState.distance(cell, capitol) == distance && Tiles::Tile::BUILDABLE_TERRAIN.include?(scenario.terrain_at(cell))
    end
  end

  test "the chosen Castle becomes a Capitol, and no longer a Castle" do
    scenario, capitol = capitol_scenario
    board = scenario.game.instantiate
    assert_includes board.silver_hexes_of("Capitol"), capitol
    assert_not_includes board.silver_hexes_of("Castle"), capitol
  end

  test "settlements 1 and 2 hexes away score, 3 hexes away do not" do
    scenario, capitol = capitol_scenario
    scenario.place_settlement(0, at: free_hexes_at(scenario, capitol, 1).first)
    scenario.place_settlement(0, at: free_hexes_at(scenario, capitol, 2).first)
    scenario.place_settlement(0, at: free_hexes_at(scenario, capitol, 3).first)
    assert_equal 2, scenario.score_for("capitol", 0)
    assert_equal 0, scenario.score_for("capitol", 1)
  end

  test "a settlement near two Capitols scores once" do
    scenario, capitol = capitol_scenario
    other = scenario.game.instantiate.silver_hexes_of("Castle").first
    scenario.game.update!(decree: { "name" => "capitol", "hexes" => [ capitol, other ] })
    scenario.game.board = nil
    spot = free_hexes_at(scenario, capitol, 1).first
    scenario.place_settlement(0, at: spot)
    assert_equal 1, scenario.score_for("capitol", 0)
  end
end
