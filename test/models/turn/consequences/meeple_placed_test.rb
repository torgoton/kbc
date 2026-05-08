require "test_helper"

class Turn::Consequences::MeeplePlacedTest < ActiveSupport::TestCase
  def setup
    @game = games(:game2player)
    @gp = @game.game_players.find { |g| g.order == 0 }
    @gp.update!(supply: { "settlements" => 40, "warriors" => 2, "ships" => 1, "wagons" => 1 })
    @game.instantiate
  end

  test "apply! places a warrior and decrements warriors supply" do
    Turn::Consequences::MeeplePlaced.new(at: Coordinate.new(5, 7), kind: "warrior", player: 0).apply!(@game)
    assert_equal "warrior", @game.board_contents.meeple_at(5, 7)
    assert_equal 0, @game.board_contents.player_at(5, 7)
    assert_equal 1, @gp.warriors_remaining
  end

  test "apply! places a ship and decrements ships supply" do
    Turn::Consequences::MeeplePlaced.new(at: Coordinate.new(5, 7), kind: "ship", player: 0).apply!(@game)
    assert_equal "ship", @game.board_contents.meeple_at(5, 7)
    assert_equal 0, @gp.ships_remaining
  end

  test "apply! places a wagon and decrements wagons supply" do
    Turn::Consequences::MeeplePlaced.new(at: Coordinate.new(5, 7), kind: "wagon", player: 0).apply!(@game)
    assert_equal "wagon", @game.board_contents.meeple_at(5, 7)
    assert_equal 0, @gp.wagons_remaining
  end

  test "unapply! removes the meeple and restores the supply" do
    c = Turn::Consequences::MeeplePlaced.new(at: Coordinate.new(5, 7), kind: "warrior", player: 0)
    c.apply!(@game)
    c.unapply!(@game)
    assert_nil @game.board_contents.player_at(5, 7)
    assert_equal 2, @gp.warriors_remaining
  end

  test "to_h round-trips through from_h" do
    c = Turn::Consequences::MeeplePlaced.new(at: Coordinate.new(5, 7), kind: "warrior", player: 0)
    h = c.to_h
    assert_equal "meeple_placed", h["type"]
    assert_equal c, Turn::Consequences::MeeplePlaced.from_h(h)
  end

  test "factory dispatches by type" do
    c = Turn::Consequences::MeeplePlaced.new(at: Coordinate.new(5, 7), kind: "ship", player: 0)
    assert_equal c, Turn::Consequences.from_h(c.to_h)
  end
end
