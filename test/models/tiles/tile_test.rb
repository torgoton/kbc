require "test_helper"

# Tests for the Tile base class interface.
# Does not reference any subclass — subclass-specific behaviour lives in subclass tests.

class Tiles::TileTest < ActiveSupport::TestCase
  test "valid_destinations returns empty array" do
    assert_equal [], Tiles::Tile.new(0).valid_destinations(board_contents: with_terrain(BoardState.new, nil), player_order: 0)
  end

  test "selectable_settlements returns empty array" do
    assert_equal [], Tiles::Tile.new(0).selectable_settlements(player_order: 0, board_contents: with_terrain(BoardState.new, nil))
  end

  test "activatable? returns false when no terrain defined" do
    assert_not Tiles::Tile.new(0).activatable?(player_order: 0, board_contents: with_terrain(BoardState.new, nil))
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

  test "resettles? returns false by default" do
    assert_not Tiles::Tile.new(0).resettles?
  end

  test "repeats_build? returns false and build_quota is 1 by default" do
    assert_not Tiles::Tile.new(0).repeats_build?
    assert_equal 1, Tiles::Tile.new(0).build_quota
  end

  test "pickup_score is nil by default" do
    assert_nil Tiles::Tile.new(0).pickup_score
  end

  test "tile_category identifies the category each concrete tile belongs to" do
    assert_equal "permanent", Tiles::Permanent::MandatoryTile.new(0).tile_category
    assert_equal "location", Tiles::Location::FarmTile.new(0).tile_category
    assert_equal "nomad", Tiles::Nomad::OutpostTile.new(0).tile_category
    assert_equal "bonus", Tiles::Bonus.new(0).tile_category
  end

  test "tile_description returns the default placeholder when no DESCRIPTION constant is defined" do
    assert_equal "should be overridden", Tiles::Tile.new(0).tile_description
  end

  test "tile_description returns the tile's own DESCRIPTION constant when defined" do
    assert_equal Tiles::Location::FarmTile::DESCRIPTION, Tiles::Location::FarmTile.new(0).tile_description
  end

  # test "class_description reflects each category's own text" do
  #   assert_equal "Usable every turn for the entire game", Tiles::Permanent::MandatoryTile.new(0).class_description
  #   assert_equal Tiles::Location::CLASS_DESCRIPTION, Tiles::Location::FarmTile.new(0).class_description
  #   assert_equal Tiles::Nomad::CLASS_DESCRIPTION, Tiles::Nomad::OutpostTile.new(0).class_description
  # end

  test "description assembles tile name, tile description, and class description with HTML allowed" do
    expected = "Farm<br>#{Tiles::Location::FarmTile::DESCRIPTION}<br><br>#{Tiles::Location::CLASS_DESCRIPTION}<br>"
    assert_equal expected, Tiles::Location::FarmTile.new(0).description
  end

  test "selectable_settlements excludes city_hall hexes" do
    state = BoardState.new
    state.place_settlement(5, 5, 0)
    state.place_city_hall_hex(6, 5, 0)
    # Use a movement tile stub that has moves_settlement? = true and some valid destination
    tile = Tiles::Location::BarnTile.new(0)
    all_grass = Object.new
    all_grass.define_singleton_method(:terrain_at) { |r, c| "G" }
    result = tile.selectable_settlements(player_order: 0, board_contents: with_terrain(state, all_grass), hand: "G")
    assert_includes result, [ 5, 5 ]
    assert_not_includes result, [ 6, 5 ]
  end
end
