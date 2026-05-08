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

  test "immediate_score returns 3 points for the treasure goal" do
    assert_equal({ "goal" => "treasure", "points" => 3 }, @tile.immediate_score)
  end
end
