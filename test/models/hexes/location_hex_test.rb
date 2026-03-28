require "test_helper"

class Hexes::LocationHexTest < ActiveSupport::TestCase
  test "outline_color is gold" do
    assert_equal "gold", Hexes::LocationHex.new.outline_color
  end
end
