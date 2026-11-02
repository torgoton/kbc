require "test_helper"

# Plateaus decree: any build next to empty mountains may be moved to one of them. The choice is
# pending (nothing else can be done) until a mountain or the built hex is clicked.
class PlateausScenarioTest < ActiveSupport::TestCase
  def plateau_scenario(decree: { "name" => "plateaus" })
    scenario = GameScenario.new(hands: { 0 => "G", 1 => "D" })
    scenario.game.update!(decree:)
    scenario.game.board = nil
    scenario
  end

  # A grass hex touching mountains, and a grass hex touching none.
  def spots(scenario)
    contents = scenario.game.tap(&:instantiate).board_contents
    grass = BoardState::MAIN_CELLS.select { |c| scenario.terrain_at(c) == "G" }
    near = grass.find { |c| contents.neighbors(*c).any? { |n| scenario.terrain_at(n) == "M" } }
    far = grass.find { |c| contents.neighbors(*c).none? { |n| scenario.terrain_at(n) == "M" } }
    mountains = contents.neighbors(*near).select { |n| scenario.terrain_at(n) == "M" }
    [ near, far, mountains ]
  end

  test "building next to mountains highlights them and the built hex, and pauses everything else" do
    scenario = plateau_scenario
    near, _, mountains = spots(scenario)
    scenario.build_settlement(at: near)

    assert_equal ([ near ] + mountains).to_set, scenario.buildable_cells.to_set
    assert_match(/move to mountain or click again/, scenario.turn_state)
    assert_not scenario.turn_endable?
    assert_raises(GameScenario::IllegalMove) { scenario.end_turn }
  end

  test "clicking a mountain moves the settlement there and logs it" do
    scenario = plateau_scenario
    near, _, mountains = spots(scenario)
    scenario.build_settlement(at: near)
    scenario.build_settlement(at: mountains.first)

    assert_equal 0, scenario.owner_at(mountains.first)
    assert_nil scenario.owner_at(near)
    assert_equal "plateau_move", scenario.moves.last.action
    assert_equal Game::MANDATORY_COUNT - 1, scenario.mandatory_remaining
    assert_no_match(/click again/, scenario.turn_state)
  end

  test "clicking the built hex again leaves it, with no log entry" do
    scenario = plateau_scenario
    near, = spots(scenario)
    scenario.build_settlement(at: near)
    scenario.build_settlement(at: near)

    assert_equal 0, scenario.owner_at(near)
    assert_not_includes scenario.moves.pluck(:action), "plateau_move"
    assert_no_match(/click again/, scenario.turn_state)
  end

  test "a build with no mountain next to it, or without the decree, is not paused" do
    scenario = plateau_scenario
    _, far, = spots(scenario)
    scenario.build_settlement(at: far)
    assert_no_match(/click again/, scenario.turn_state)

    plain = plateau_scenario(decree: nil)
    near, = spots(plain)
    plain.build_settlement(at: near)
    assert_no_match(/click again/, plain.turn_state)
  end

  test "undo takes back the whole build, moved or not" do
    scenario = plateau_scenario
    near, _, mountains = spots(scenario)
    scenario.build_settlement(at: near)
    scenario.build_settlement(at: mountains.first)
    scenario.undo

    assert_nil scenario.owner_at(near)
    assert_nil scenario.owner_at(mountains.first)
    assert_equal Game::MANDATORY_COUNT, scenario.mandatory_remaining

    scenario.build_settlement(at: near)
    scenario.undo
    assert_nil scenario.owner_at(near)
    assert_no_match(/click again/, scenario.turn_state)
  end

  test "tile builds are offered the move too" do
    scenario = plateau_scenario
    near, _, mountains = spots(scenario)
    scenario.give_tile(0, "FarmTile", from: [ 0, 0 ])
    scenario.activate_tile(:farm)
    scenario.build_settlement(at: near)
    assert_match(/move to mountain or click again/, scenario.turn_state)

    scenario.build_settlement(at: mountains.first)
    assert_equal 0, scenario.owner_at(mountains.first)
    assert scenario.tile_used?(0, "FarmTile")
  end

  test "a warrior placed by Barracks may move to a mountain too" do
    scenario = plateau_scenario
    near, _, mountains = spots(scenario)
    scenario.give_warriors(0, 1)
    scenario.give_tile(0, "BarracksTile", from: [ 0, 0 ])
    scenario.activate_tile(:barracks)
    scenario.move_meeple_step(to: near)
    assert_match(/move to mountain or click again/, scenario.turn_state)

    scenario.move_meeple_step(to: mountains.first)
    assert_equal "warrior", scenario.meeple_at(mountains.first)
    assert_nil scenario.owner_at(near)
  end
end
