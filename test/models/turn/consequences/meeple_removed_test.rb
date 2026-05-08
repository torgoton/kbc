require "test_helper"

class Turn::Consequences::MeepleRemovedTest < ActiveSupport::TestCase
  def setup
    @game = games(:game2player)
    @gp = @game.game_players.find { |g| g.order == 0 }
    @gp.update!(supply: { "settlements" => 40, "warriors" => 1, "ships" => 0, "wagons" => 0 })
    @game.instantiate
    @game.board_contents.place_warrior(5, 7, 0)
  end

  test "apply! removes the meeple and increments supply" do
    Turn::Consequences::MeepleRemoved.new(at: Coordinate.new(5, 7), kind: "warrior", player: 0).apply!(@game)
    assert_nil @game.board_contents.player_at(5, 7)
    assert_equal 2, @gp.warriors_remaining
  end

  test "unapply! restores the meeple at the hex and decrements supply" do
    c = Turn::Consequences::MeepleRemoved.new(at: Coordinate.new(5, 7), kind: "warrior", player: 0)
    c.apply!(@game)
    c.unapply!(@game)
    assert_equal "warrior", @game.board_contents.meeple_at(5, 7)
    assert_equal 0, @gp.player_at_meeple_supply_count("warrior") if @gp.respond_to?(:player_at_meeple_supply_count)
    assert_equal 1, @gp.warriors_remaining
  end

  test "to_h round-trips through from_h" do
    c = Turn::Consequences::MeepleRemoved.new(at: Coordinate.new(5, 7), kind: "warrior", player: 0)
    h = c.to_h
    assert_equal "meeple_removed", h["type"]
    assert_equal c, Turn::Consequences::MeepleRemoved.from_h(h)
  end

  test "factory dispatches by type" do
    c = Turn::Consequences::MeepleRemoved.new(at: Coordinate.new(5, 7), kind: "warrior", player: 0)
    assert_equal c, Turn::Consequences.from_h(c.to_h)
  end
end
