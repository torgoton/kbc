require "test_helper"

class Turn::Consequences::PermanentTileConsumedTest < ActiveSupport::TestCase
  def setup
    @game = Game.create!(state: "waiting")
    @game.add_player(users(:chris))
    @game.add_player(users(:paula))
    @game.start
    @game.reload
    @player = @game.game_players.find { |gp| gp.order == 0 }
    @player.tiles = [ { "klass" => "CityHallTile", "from" => "[2, 5]", "used" => false } ]
  end

  test "apply marks tile used and permanent" do
    Turn::Consequences::PermanentTileConsumed.new(klass: "CityHallTile", player: @player.order).apply!(@game)

    tile = @player.tiles.first
    assert tile["used"]
    assert tile["permanent"]
  end

  test "unapply marks tile unused and non-permanent" do
    @player.mark_tile_permanently_used!("CityHallTile")

    Turn::Consequences::PermanentTileConsumed.new(klass: "CityHallTile", player: @player.order).unapply!(@game)

    tile = @player.tiles.first
    assert_equal false, tile["used"]
    assert_nil tile["permanent"]
  end

  test "to_h round-trips through from_h" do
    consequence = Turn::Consequences::PermanentTileConsumed.new(klass: "CityHallTile", player: 0)

    assert_equal consequence, Turn::Consequences::PermanentTileConsumed.from_h(consequence.to_h)
  end
end
