require "test_helper"

class Hexes::SpecialHexTest < ActiveSupport::TestCase
  test "outline_color is black" do
    assert_equal "black", Hexes::SpecialHex.new.outline_color
  end
end
