require "test_helper"

# CrossroadsTile lets its holder draw an extra card at the end of each turn.
# It has no on-board action of its own.
class CrossroadsTileTest < ActiveSupport::TestCase
  test "draws an extra card at the end of the turn while held" do
    scenario = GameScenario.new(hands: { 0 => "G" })
    scenario.give_tile(0, "CrossroadsTile", from: [ 0, 0 ])

    scenario.end_turn

    assert_equal %w[T G], scenario.hand(0)
  end

  test "is never offered as a selectable tile action" do
    scenario = GameScenario.new
    scenario.give_tile(0, "CrossroadsTile", from: [ 0, 0 ])

    assert_not_includes scenario.available_tile_actions(0), "CrossroadsTile"
  end
end
