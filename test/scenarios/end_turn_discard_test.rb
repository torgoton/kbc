require "test_helper"

# At the end of a turn the player's whole hand goes to the discard, used or not (1 card, 2 with
# Crossroads, 3 with Crossroads doubled by Bazaar), and a fresh hand is drawn.
class EndTurnDiscardTest < ActiveSupport::TestCase
  def play_out(scenario)
    scenario.set_mandatory(0)
    scenario.end_turn
  end

  test "a single unused card is discarded" do
    scenario = GameScenario.new(hands: { 0 => "G" }, deck: %w[T C D F])
    play_out(scenario)

    assert_includes scenario.game.discard, "G"
    assert_equal [ "T" ], scenario.game.game_players.find { |gp| gp.order == 0 }.hand
  end

  test "a multi-card hand is discarded in full, whether or not it was used" do
    scenario = GameScenario.new(hands: { 0 => %w[G T C] }, deck: %w[D F D F])
    play_out(scenario)

    assert_equal 3, (scenario.game.discard & %w[G T C]).size
  end

  test "Crossroads draws a two-card hand next time" do
    scenario = GameScenario.new(hands: { 0 => "G" }, deck: %w[T C D F])
    scenario.give_tile(0, "CrossroadsTile", from: [ 0, 0 ])
    play_out(scenario)

    assert_includes scenario.game.discard, "G"
    assert_equal 2, scenario.game.game_players.find { |gp| gp.order == 0 }.hand.size
  end
end
