require "test_helper"

class Turn::Consequences::PieceRemovedTest < ActiveSupport::TestCase
  def setup
    @game = Game.create!(state: "waiting")
    @game.add_player(users(:chris))
    @game.add_player(users(:paula))
    @game.start
    @game.reload
    @game.instantiate
    @player = @game.game_players.find { |gp| gp.order == 1 }
  end

  test "apply removes settlement and returns it to supply" do
    @game.board_contents.place_settlement(4, 4, @player.order)
    before = @player.settlements_remaining

    Turn::Consequences::PieceRemoved.new(at: Coordinate.new(4, 4), kind: nil, player: @player.order).apply!(@game)

    assert_nil @game.board_contents.player_at(4, 4)
    assert_equal before + 1, @player.settlements_remaining
  end

  test "unapply restores warrior and removes it from supply" do
    @player.add_warriors!(1)
    before = @player.warriors_remaining
    consequence = Turn::Consequences::PieceRemoved.new(at: Coordinate.new(4, 4), kind: "warrior", player: @player.order)

    consequence.unapply!(@game)

    assert @game.board_contents.warrior_at?(4, 4)
    assert_equal before - 1, @player.warriors_remaining
  end

  test "to_h round-trips through from_h" do
    consequence = Turn::Consequences::PieceRemoved.new(at: Coordinate.new(4, 4), kind: "ship", player: 1)

    assert_equal consequence, Turn::Consequences::PieceRemoved.from_h(consequence.to_h)
  end
end
