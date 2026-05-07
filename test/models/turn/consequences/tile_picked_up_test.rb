require "test_helper"

class Turn::Consequences::TilePickedUpTest < ActiveSupport::TestCase
  def setup
    @game = games(:game2player)
    @game.board_contents.place_tile(3, 4, "FarmTile", 2)
    @from = Coordinate.new(3, 4)
  end

  def player(order) = @game.game_players.find { |gp| gp.order == order }

  def consequence(from: @from, klass: "FarmTile", player: 0)
    Turn::Consequences::TilePickedUp.new(from:, klass:, player:)
  end

  test "decrements the tile qty on the board" do
    consequence.apply!(@game)
    assert_equal 1, @game.board_contents.tile_qty(3, 4)
  end

  test "adds the tile to the player's tiles with from = coord key" do
    consequence(player: 0).apply!(@game)
    held = player(0).tiles
    assert_equal 1, held.size
    assert_equal "FarmTile", held.first["klass"]
    assert_equal "[3, 4]", held.first["from"]
  end

  test "appends the location to the player's taken_from" do
    consequence(player: 0).apply!(@game)
    assert_equal [ "[3, 4]" ], player(0).taken_from
  end
end
