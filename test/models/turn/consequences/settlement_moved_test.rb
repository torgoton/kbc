require "test_helper"

class Turn::Consequences::SettlementMovedTest < ActiveSupport::TestCase
  def setup
    @game = games(:game2player)
    @game.instantiate
  end

  test "apply! moves the settlement from `from` to `to`" do
    @game.board_contents.place_settlement(5, 5, 0)
    Turn::Consequences::SettlementMoved.new(
      from: Coordinate.new(5, 5), to: Coordinate.new(7, 7), player: 0
    ).apply!(@game)
    assert_nil @game.board_contents.player_at(5, 5)
    assert_equal 0, @game.board_contents.player_at(7, 7)
  end

  test "unapply! moves the settlement back" do
    @game.board_contents.place_settlement(5, 5, 0)
    c = Turn::Consequences::SettlementMoved.new(
      from: Coordinate.new(5, 5), to: Coordinate.new(7, 7), player: 0
    )
    c.apply!(@game)
    c.unapply!(@game)
    assert_equal 0, @game.board_contents.player_at(5, 5)
    assert_nil @game.board_contents.player_at(7, 7)
  end

  test "to_h round-trips through from_h" do
    c = Turn::Consequences::SettlementMoved.new(from: Coordinate.new(5, 5), to: Coordinate.new(7, 7), player: 0)
    h = c.to_h
    assert_equal "settlement_moved", h["type"]
    assert_equal "[5, 5]", h["from"]
    assert_equal "[7, 7]", h["to"]
    assert_equal c, Turn::Consequences::SettlementMoved.from_h(h)
  end

  test "factory dispatches by type" do
    c = Turn::Consequences::SettlementMoved.new(from: Coordinate.new(5, 5), to: Coordinate.new(7, 7), player: 0)
    assert_equal c, Turn::Consequences.from_h(c.to_h)
  end
end
