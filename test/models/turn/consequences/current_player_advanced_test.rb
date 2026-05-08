require "test_helper"

class Turn::Consequences::CurrentPlayerAdvancedTest < ActiveSupport::TestCase
  def setup
    @game = games(:game2player)
    @gp0 = @game.game_players.find { |g| g.order == 0 }
    @gp1 = @game.game_players.find { |g| g.order == 1 }
    @game.current_player = @gp0
    @game.save!
  end

  test "apply! sets current_player to the next-order GamePlayer" do
    Turn::Consequences::CurrentPlayerAdvanced.new(prior_order: 0, next_order: 1).apply!(@game)
    assert_equal @gp1, @game.current_player
  end

  test "unapply! restores prior current_player" do
    c = Turn::Consequences::CurrentPlayerAdvanced.new(prior_order: 0, next_order: 1)
    c.apply!(@game)
    c.unapply!(@game)
    assert_equal @gp0, @game.current_player
  end

  test "to_h round-trips through from_h" do
    c = Turn::Consequences::CurrentPlayerAdvanced.new(prior_order: 0, next_order: 1)
    assert_equal({ "type" => "current_player_advanced", "prior_order" => 0, "next_order" => 1 }, c.to_h)
    assert_equal c, Turn::Consequences::CurrentPlayerAdvanced.from_h(c.to_h)
  end

  test "factory dispatches by type" do
    c = Turn::Consequences::CurrentPlayerAdvanced.new(prior_order: 0, next_order: 1)
    assert_equal c, Turn::Consequences.from_h(c.to_h)
  end
end
