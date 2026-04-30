require "test_helper"

# Tests for the Tile base class interface.
# Does not reference any subclass — subclass-specific behaviour lives in subclass tests.

class Tiles::TileTest < ActiveSupport::TestCase
  test "valid_destinations returns empty array" do
    assert_equal [], Tiles::Tile.new(0).valid_destinations(board_contents: BoardState.new, board: nil, player_order: 0)
  end

  test "selectable_settlements returns empty array" do
    assert_equal [], Tiles::Tile.new(0).selectable_settlements(player_order: 0, board_contents: BoardState.new, board: nil)
  end

  test "activatable? returns false when no terrain defined" do
    assert_not Tiles::Tile.new(0).activatable?(player_order: 0, board_contents: BoardState.new, board: nil)
  end

  test "builds_settlement? returns false" do
    assert_not Tiles::Tile.new(0).builds_settlement?
  end

  test "from_hash raises ArgumentError for unknown klass" do
    assert_raises(ArgumentError) { Tiles::Tile.from_hash("klass" => "BogusTimeTile") }
  end

  test "on_pickup returns nil by default" do
    assert_nil Tiles::Tile.new(0).on_pickup(game_player: nil)
  end

  test "places_meeple? returns false by default" do
    assert_not Tiles::Tile.new(0).places_meeple?
  end

  test "places_city_hall? returns false by default" do
    assert_not Tiles::Tile.new(0).places_city_hall?
  end

  test "selectable_settlements excludes city_hall hexes" do
    state = BoardState.new
    state.place_settlement(5, 5, 0)
    state.place_city_hall_hex(6, 5, 0)
    # Use a movement tile stub that has moves_settlement? = true and some valid destination
    tile = Tiles::BarnTile.new(0)
    all_grass = Object.new
    all_grass.define_singleton_method(:terrain_at) { |r, c| "G" }
    result = tile.selectable_settlements(player_order: 0, board_contents: state, board: all_grass, hand: "G")
    assert_includes result, [ 5, 5 ]
    assert_not_includes result, [ 6, 5 ]
  end
end
