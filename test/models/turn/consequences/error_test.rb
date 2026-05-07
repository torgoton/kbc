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
end
