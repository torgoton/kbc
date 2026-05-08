require "test_helper"

class Turn::Consequences::IrreversibleBoundaryTest < ActiveSupport::TestCase
  def setup
    @game = games(:game2player)
  end

  test "apply! is a no-op (marker only)" do
    assert_nothing_raised { Turn::Consequences::IrreversibleBoundary.new.apply!(@game) }
  end

  test "unapply! is a no-op (caller should never reach this)" do
    assert_nothing_raised { Turn::Consequences::IrreversibleBoundary.new.unapply!(@game) }
  end

  test "to_h round-trips through from_h" do
    c = Turn::Consequences::IrreversibleBoundary.new
    assert_equal({ "type" => "irreversible_boundary" }, c.to_h)
    assert_equal c, Turn::Consequences::IrreversibleBoundary.from_h(c.to_h)
  end

  test "factory dispatches by type" do
    c = Turn::Consequences::IrreversibleBoundary.new
    assert_equal c, Turn::Consequences.from_h(c.to_h)
  end

  test "two instances are equal" do
    assert_equal Turn::Consequences::IrreversibleBoundary.new, Turn::Consequences::IrreversibleBoundary.new
  end
end
