require "test_helper"

class Turn::Consequences::CityHallSupplyDecrementedTest < ActiveSupport::TestCase
  def setup
    @game = Game.create!(state: "waiting")
    @game.add_player(users(:chris))
    @game.add_player(users(:paula))
    @game.start
    @game.reload
    @player = @game.game_players.find { |gp| gp.order == 0 }
    @player.add_city_halls!(1)
  end

  test "apply decrements city hall supply" do
    Turn::Consequences::CityHallSupplyDecremented.new(player: @player.order).apply!(@game)

    assert_equal 0, @player.city_halls_remaining
  end

  test "unapply increments city hall supply" do
    @player.decrement_city_hall_supply!

    Turn::Consequences::CityHallSupplyDecremented.new(player: @player.order).unapply!(@game)

    assert_equal 1, @player.city_halls_remaining
  end

  test "to_h round-trips through from_h" do
    consequence = Turn::Consequences::CityHallSupplyDecremented.new(player: 0)

    assert_equal consequence, Turn::Consequences::CityHallSupplyDecremented.from_h(consequence.to_h)
  end
end
