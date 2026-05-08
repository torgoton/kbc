require "test_helper"

class Turn::Consequences::NomadTilesExpiredTest < ActiveSupport::TestCase
  def setup
    @game = games(:game2player)
    @gp = @game.game_players.find { |g| g.order == 0 }
  end

  test "apply! removes the expired tiles from the player" do
    @gp.tiles = [
      { "klass" => "FarmTile", "from" => "[3, 4]", "used" => true },
      { "klass" => "DonationGrassTile", "from" => "[5, 6]", "used" => true, "expires_on_turn" => 4 }
    ]
    expired = [ @gp.tiles.last.deep_dup ]
    Turn::Consequences::NomadTilesExpired.new(player: 0, expired_tiles: expired).apply!(@game)
    assert_equal 1, @gp.tiles.size
    assert_equal "FarmTile", @gp.tiles.first["klass"]
  end

  test "unapply! restores the expired tiles" do
    @gp.tiles = [ { "klass" => "FarmTile", "from" => "[3, 4]", "used" => true } ]
    expired = [ { "klass" => "DonationGrassTile", "from" => "[5, 6]", "used" => true, "expires_on_turn" => 4 } ]
    c = Turn::Consequences::NomadTilesExpired.new(player: 0, expired_tiles: expired)
    c.apply!(@game)  # no-op since none of the player's tiles are expired
    c.unapply!(@game)
    assert_equal 2, @gp.tiles.size
  end

  test "to_h round-trips through from_h" do
    expired = [ { "klass" => "X", "from" => "[0, 0]", "used" => true } ]
    c = Turn::Consequences::NomadTilesExpired.new(player: 0, expired_tiles: expired)
    assert_equal "nomad_tiles_expired", c.to_h["type"]
    assert_equal c, Turn::Consequences::NomadTilesExpired.from_h(c.to_h)
  end

  test "factory dispatches by type" do
    c = Turn::Consequences::NomadTilesExpired.new(player: 0, expired_tiles: [])
    assert_equal c, Turn::Consequences.from_h(c.to_h)
  end
end
