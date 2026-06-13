require "test_helper"

# FortTile draws the top deck card and grants one extra settlement build on
# that terrain - adjacent to an existing settlement if possible, otherwise
# anywhere on that terrain - without consuming the mandatory build count.
# Activating it cannot be undone.
class FortTileTest < ActiveSupport::TestCase
  # GameScenario::DEFAULT_DECK is %w[T G C D F], so activating Fort always
  # draws "T" (Timber) on a fresh scenario.
  DRAWN_TERRAIN = "T".freeze

  test "draws a card and builds an extra settlement adjacent to an existing one on the drawn terrain" do
    scenario = GameScenario.new
    target = scenario.empty_hexes(DRAWN_TERRAIN, 1).first
    adjacent_spot = scenario.neighbors(target).find { |n| scenario.owner_at(n).nil? }
    scenario.place_settlement(0, at: adjacent_spot)
    scenario.give_tile(0, "FortTile", from: [ 0, 0 ])

    scenario.activate_fort_tile
    scenario.build_settlement(at: target)

    assert_equal 0, scenario.owner_at(target)
    assert_equal Game::SETTLEMENTS_PER_PLAYER - 1, scenario.settlements_remaining(0)
    assert_equal Game::MANDATORY_COUNT, scenario.mandatory_remaining
    assert_not_includes scenario.usable_tiles(0), "FortTile"
  end

  test "builds anywhere on the drawn terrain when no settlement is adjacent to one" do
    scenario = GameScenario.new
    scenario.give_tile(0, "FortTile", from: [ 0, 0 ])
    target = scenario.empty_hexes(DRAWN_TERRAIN, 1).first

    scenario.activate_fort_tile
    scenario.build_settlement(at: target)

    assert_equal 0, scenario.owner_at(target)
    assert_equal Game::SETTLEMENTS_PER_PLAYER - 1, scenario.settlements_remaining(0)
  end

  test "rejects a build on a different terrain than the drawn card" do
    scenario = GameScenario.new
    scenario.give_tile(0, "FortTile", from: [ 0, 0 ])
    wrong_hex = scenario.empty_hexes("G", 1).first

    scenario.activate_fort_tile

    assert_raises(GameScenario::IllegalMove) { scenario.build_settlement(at: wrong_hex) }
  end

  test "activating the Fort tile cannot be undone" do
    scenario = GameScenario.new
    scenario.give_tile(0, "FortTile", from: [ 0, 0 ])

    scenario.activate_fort_tile

    assert_not scenario.undo_allowed?
  end
end
