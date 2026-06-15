require "test_helper"

class Tiles::Nomad::TreasureTileTest < ActiveSupport::TestCase
  def setup
    @tile = Tiles::Nomad::TreasureTile.new(0)
  end

  test "nomad_tile? returns true" do
    assert @tile.nomad_tile?
  end

  test "pickup_score awards 3 points to the treasure goal" do
    assert_equal [ "treasure", 3 ], @tile.pickup_score
  end

  test "DESCRIPTION is set" do
    assert_includes Tiles::Nomad::TreasureTile::DESCRIPTION, "3 points"
  end
end
