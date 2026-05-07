require "test_helper"

class Turn::Consequences::SettlementPlacedTest < ActiveSupport::TestCase
  def setup
    @game = games(:game2player)
  end

  def player(order) = @game.game_players.find { |gp| gp.order == order }

  def consequence(at: Coordinate.new(5, 7), player: 0, terrain: "G")
    Turn::Consequences::SettlementPlaced.new(at:, player:, terrain:)
  end

  test "places a settlement at the coordinate for the given player" do
    consequence(at: Coordinate.new(5, 7), player: 0).apply!(@game)
    assert_equal 0, @game.board_contents.player_at(5, 7)
  end

  test "decrements the player's settlement supply" do
    before = player(0).settlements_remaining
    consequence(player: 0).apply!(@game)
    assert_equal before - 1, player(0).settlements_remaining
  end

  test "leaves other players' supply unchanged" do
    before = player(1).settlements_remaining
    consequence(player: 0).apply!(@game)
    assert_equal before, player(1).settlements_remaining
  end

  test "equality is by value" do
    a = consequence(at: Coordinate.new(5, 7), player: 0, terrain: "G")
    b = consequence(at: Coordinate.new(5, 7), player: 0, terrain: "G")
    assert_equal a, b
  end
end
