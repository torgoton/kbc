require "test_helper"

class Turn::Consequences::CityHallPlacedTest < ActiveSupport::TestCase
  def setup
    @game = Game.create!(state: "waiting")
    @game.add_player(users(:chris))
    @game.add_player(users(:paula))
    @game.start
    @game.reload
    @game.instantiate
  end

  test "apply places city hall hexes" do
    cluster = [ Coordinate.new(4, 4), Coordinate.new(4, 5) ]

    Turn::Consequences::CityHallPlaced.new(cluster: cluster, player: 0).apply!(@game)

    assert @game.board_contents.city_hall_at?(4, 4)
    assert @game.board_contents.city_hall_at?(4, 5)
    assert_equal 0, @game.board_contents.player_at(4, 4)
  end

  test "unapply removes city hall hexes" do
    @game.board_contents.place_city_hall_hex(4, 4, 0)
    @game.board_contents.place_city_hall_hex(4, 5, 0)
    cluster = [ Coordinate.new(4, 4), Coordinate.new(4, 5) ]

    Turn::Consequences::CityHallPlaced.new(cluster: cluster, player: 0).unapply!(@game)

    assert @game.board_contents.empty?(4, 4)
    assert @game.board_contents.empty?(4, 5)
  end

  test "to_h round-trips through from_h" do
    consequence = Turn::Consequences::CityHallPlaced.new(
      cluster: [ Coordinate.new(4, 4), Coordinate.new(4, 5) ],
      player: 0
    )

    assert_equal consequence, Turn::Consequences::CityHallPlaced.from_h(consequence.to_h)
  end
end
