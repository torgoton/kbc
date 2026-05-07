require "test_helper"

class Turn::Consequences::TileDiscardedTest < ActiveSupport::TestCase
  def setup
    @game = games(:game2player)
    @gp = @game.game_players.find { |g| g.order == 0 }
  end

  test "apply! removes the tile entry matching klass + from from the player's hand" do
    @gp.tiles = [
      { "klass" => "TreasureTile", "from" => "[3, 4]", "used" => false },
      { "klass" => "FarmTile",     "from" => "[5, 6]", "used" => false }
    ]
    Turn::Consequences::TileDiscarded.new(player: 0, klass: "TreasureTile", from: "[3, 4]", used: false).apply!(@game)
    refute(@gp.tiles.any? { |t| t["klass"] == "TreasureTile" })
    assert(@gp.tiles.any? { |t| t["klass"] == "FarmTile" })
  end

  test "apply! removes only one matching entry when there are duplicates" do
    @gp.tiles = [
      { "klass" => "TreasureTile", "from" => "[3, 4]", "used" => false },
      { "klass" => "TreasureTile", "from" => "[3, 4]", "used" => false }
    ]
    Turn::Consequences::TileDiscarded.new(player: 0, klass: "TreasureTile", from: "[3, 4]", used: false).apply!(@game)
    assert_equal 1, @gp.tiles.size
  end

  test "unapply! restores the tile entry with original used state" do
    @gp.tiles = [ { "klass" => "TreasureTile", "from" => "[3, 4]", "used" => false } ]
    c = Turn::Consequences::TileDiscarded.new(player: 0, klass: "TreasureTile", from: "[3, 4]", used: false)
    c.apply!(@game)
    c.unapply!(@game)
    restored = @gp.tiles.find { |t| t["klass"] == "TreasureTile" && t["from"] == "[3, 4]" }
    refute_nil restored
    assert_equal false, restored["used"]
  end

  test "to_h round-trips through from_h" do
    c = Turn::Consequences::TileDiscarded.new(player: 0, klass: "TreasureTile", from: "[3, 4]", used: false)
    h = c.to_h
    assert_equal "tile_discarded", h["type"]
    assert_equal c, Turn::Consequences::TileDiscarded.from_h(h)
  end

  test "factory dispatches by type" do
    c = Turn::Consequences::TileDiscarded.new(player: 0, klass: "TreasureTile", from: "[3, 4]", used: false)
    assert_equal c, Turn::Consequences.from_h(c.to_h)
  end
end
