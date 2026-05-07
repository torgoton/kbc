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
end
