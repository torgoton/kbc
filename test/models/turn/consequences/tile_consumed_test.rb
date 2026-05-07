require "test_helper"

class Turn::Consequences::TileConsumedTest < ActiveSupport::TestCase
  def setup
    @game = games(:game2player)
    @player = @game.game_players.find { |gp| gp.order == 0 }
    @player.tiles = [ { "klass" => "FarmTile", "from" => "[3, 4]", "used" => false } ]
  end

  test "marks the player's tile as used" do
    Turn::Consequences::TileConsumed.new(klass: "FarmTile", player: 0).apply!(@game)
    held = @game.game_players.find { |gp| gp.order == 0 }.tiles.first
    assert_equal true, held["used"]
  end

  test "no-op if no unused tile of that klass" do
    @player.tiles = [ { "klass" => "FarmTile", "from" => "[3, 4]", "used" => true } ]
    assert_nothing_raised do
      Turn::Consequences::TileConsumed.new(klass: "FarmTile", player: 0).apply!(@game)
    end
  end

  test "unapply! marks the tile unused again" do
    gp = player(0)
    gp.tiles = []
    gp.receive_tile!("FarmTile", from: "[2, 3]")
    c = Turn::Consequences::TileConsumed.new(klass: "FarmTile", player: 0)
    c.apply!(@game)
    refute_nil gp.tiles.find { |t| t["klass"] == "FarmTile" && t["used"] }
    c.unapply!(@game)
    assert_nil gp.tiles.find { |t| t["klass"] == "FarmTile" && t["used"] }
    refute_nil gp.tiles.find { |t| t["klass"] == "FarmTile" }
  end

  def player(order) = @game.game_players.find { |gp| gp.order == order }
end
