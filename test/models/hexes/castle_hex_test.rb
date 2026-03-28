require "test_helper"

class Hexes::CastleHexTest < ActiveSupport::TestCase
  test "outline_color is silver" do
    assert_equal "silver", Hexes::CastleHex.new.outline_color
  end
end
