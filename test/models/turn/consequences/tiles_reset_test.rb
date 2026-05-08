require "test_helper"

class Turn::Consequences::TilesResetTest < ActiveSupport::TestCase
  def setup
    @game = games(:game2player)
    @gp = @game.game_players.find { |g| g.order == 1 }
  end

  test "apply! marks all non-permanent tiles as used: false on the named player" do
    @gp.tiles = [
      { "klass" => "FarmTile", "from" => "[3, 4]", "used" => true },
      { "klass" => "OracleTile", "from" => "[5, 6]", "used" => true, "permanent" => true }
    ]
    Turn::Consequences::TilesReset.new(player: 1, prior_tiles: @gp.tiles.deep_dup).apply!(@game)
    farm = @gp.tiles.find { |t| t["klass"] == "FarmTile" }
    oracle = @gp.tiles.find { |t| t["klass"] == "OracleTile" }
    assert_equal false, farm["used"]
    assert_equal true, oracle["used"]  # permanent stays used
  end

  test "unapply! restores prior_tiles" do
    prior = [
      { "klass" => "FarmTile", "from" => "[3, 4]", "used" => true },
      { "klass" => "OracleTile", "from" => "[5, 6]", "used" => true }
    ]
    @gp.tiles = prior.deep_dup
    c = Turn::Consequences::TilesReset.new(player: 1, prior_tiles: prior)
    c.apply!(@game)
    c.unapply!(@game)
    assert_equal prior, @gp.tiles
  end

  test "to_h round-trips through from_h" do
    c = Turn::Consequences::TilesReset.new(player: 1, prior_tiles: [ { "klass" => "FarmTile", "used" => true } ])
    assert_equal "tiles_reset", c.to_h["type"]
    assert_equal c, Turn::Consequences::TilesReset.from_h(c.to_h)
  end

  test "factory dispatches by type" do
    c = Turn::Consequences::TilesReset.new(player: 1, prior_tiles: [])
    assert_equal c, Turn::Consequences.from_h(c.to_h)
  end
end
