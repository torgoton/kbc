require "test_helper"

class Tiles::Nomad::TreasureTileTest < ActiveSupport::TestCase
  def setup
    @tile = Tiles::Nomad::TreasureTile.new(0)
  end

  test "nomad_tile? returns true" do
    assert @tile.nomad_tile?
  end

  test "DESCRIPTION is set" do
    assert_includes Tiles::Nomad::TreasureTile::DESCRIPTION, "3 points"
  end
end
