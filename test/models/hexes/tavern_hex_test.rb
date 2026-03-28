require "test_helper"

class Hexes::TavernHexTest < ActiveSupport::TestCase
  test "outline_color is gold (inherited from LocationHex)" do
    assert_equal "gold", Hexes::TavernHex.new.outline_color
  end
end
