require "test_helper"

class Tiles::FarmTileTest < ActiveSupport::TestCase
  test "build_terrain returns G" do
    assert_equal "G", Tiles::FarmTile.new(0).build_terrain
  end
end
