require "test_helper"

class Hexes::HexTest < ActiveSupport::TestCase
  test "can be instantiated" do
    assert_instance_of Hexes::Hex, Hexes::Hex.new
  end
end
