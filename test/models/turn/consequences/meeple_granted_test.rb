require "test_helper"

class Turn::Consequences::MeepleGrantedTest < ActiveSupport::TestCase
  def setup
    @game = games(:game2player)
  end

  def player(order) = @game.game_players.find { |gp| gp.order == order }

  test "apply! increments the named meeple supply for the named player" do
    before = player(0).warriors_remaining
    Turn::Consequences::MeepleGranted.new(player: 0, kind: "warrior", qty: 2).apply!(@game)
    assert_equal before + 2, player(0).warriors_remaining
  end

  test "apply! routes by kind: ship updates ships, wagon updates wagons" do
    ship_before = player(0).ships_remaining
    wagon_before = player(0).wagons_remaining
    Turn::Consequences::MeepleGranted.new(player: 0, kind: "ship", qty: 1).apply!(@game)
    Turn::Consequences::MeepleGranted.new(player: 0, kind: "wagon", qty: 1).apply!(@game)
    assert_equal ship_before + 1, player(0).ships_remaining
    assert_equal wagon_before + 1, player(0).wagons_remaining
  end

  test "apply! does not affect other players" do
    before = player(1).warriors_remaining
    Turn::Consequences::MeepleGranted.new(player: 0, kind: "warrior", qty: 2).apply!(@game)
    assert_equal before, player(1).warriors_remaining
  end

  test "unapply! restores the prior supply" do
    before = player(0).warriors_remaining
    c = Turn::Consequences::MeepleGranted.new(player: 0, kind: "warrior", qty: 2)
    c.apply!(@game)
    c.unapply!(@game)
    assert_equal before, player(0).warriors_remaining
  end

  test "to_h round-trips through from_h" do
    c = Turn::Consequences::MeepleGranted.new(player: 0, kind: "warrior", qty: 2)
    assert_equal({ "type" => "meeple_granted", "player" => 0, "kind" => "warrior", "qty" => 2 }, c.to_h)
    assert_equal c, Turn::Consequences::MeepleGranted.from_h(c.to_h)
  end

  test "factory dispatches by type" do
    c = Turn::Consequences::MeepleGranted.new(player: 0, kind: "ship", qty: 1)
    assert_equal c, Turn::Consequences.from_h(c.to_h)
  end

  test "equality is by value" do
    a = Turn::Consequences::MeepleGranted.new(player: 0, kind: "warrior", qty: 2)
    b = Turn::Consequences::MeepleGranted.new(player: 0, kind: "warrior", qty: 2)
    assert_equal a, b
  end
end
