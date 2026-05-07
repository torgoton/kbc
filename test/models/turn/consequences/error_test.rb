require "test_helper"

class Turn::Consequences::ErrorTest < ActiveSupport::TestCase
  test "apply! is a no-op" do
    game = games(:game2player)
    Turn::Consequences::Error.new(message: "nope").apply!(game)
  end

  test "unapply! is a no-op" do
    game = games(:game2player)
    Turn::Consequences::Error.new(message: "nope").unapply!(game)
  end

  test "error? is true" do
    assert Turn::Consequences::Error.new(message: "nope").error?
  end

  test "to_h round-trips through from_h" do
    c = Turn::Consequences::Error.new(message: "nope")
    assert_equal({ "type" => "error", "message" => "nope" }, c.to_h)
    assert_equal c, Turn::Consequences::Error.from_h(c.to_h)
  end
end
