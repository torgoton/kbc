require "test_helper"

# Coordinate is a value object representing a hex grid position.
#
# Three formats exist in the system:
#   - Integer pair:  row=2, col=7          (computation, BoardState method args)
#   - Key string:    "[2, 7]"              (DB: moves.from/to, tiles[*]["from"])
#   - Controller:    params[:row], params[:col]  (integers submitted from browser)
#
# Coordinate owns the boundary between key strings and integer pairs.
# The DOM format ("map-cell-2-7") is eliminated at the JS layer.

class CoordinateTest < ActiveSupport::TestCase
  # --- Construction ---

  test "new stores row and col" do
    coord = Coordinate.new(2, 7)
    assert_equal 2, coord.row
    assert_equal 7, coord.col
  end

  test "new coerces string integers (as received from controller params)" do
    coord = Coordinate.new("2", "7")
    assert_equal 2, coord.row
    assert_equal 7, coord.col
  end

  test "new raises on non-numeric string" do
    assert_raises(ArgumentError) { Coordinate.new("abc", 7) }
  end

  test "new raises on nil" do
    assert_raises(TypeError) { Coordinate.new(nil, 7) }
  end

  test "coordinate is frozen (immutable value object)" do
    assert Coordinate.new(2, 7).frozen?
  end

  # --- Parsing from DB key string ---

  test "from_key parses '[row, col]' format" do
    coord = Coordinate.from_key("[2, 7]")
    assert_equal 2, coord.row
    assert_equal 7, coord.col
  end

  test "from_key handles grid boundary values" do
    assert_equal 0,  Coordinate.from_key("[0, 0]").row
    assert_equal 0,  Coordinate.from_key("[0, 0]").col
    assert_equal 19, Coordinate.from_key("[19, 19]").row
    assert_equal 19, Coordinate.from_key("[19, 19]").col
  end

  # --- Serialization to DB key string ---

  test "to_key produces '[row, col]' string" do
    assert_equal "[2, 7]",   Coordinate.new(2, 7).to_key
    assert_equal "[0, 0]",   Coordinate.new(0, 0).to_key
    assert_equal "[19, 19]", Coordinate.new(19, 19).to_key
  end

  test "from_key and to_key are inverses" do
    coord = Coordinate.new(5, 13)
    assert_equal coord, Coordinate.from_key(coord.to_key)
  end

  # --- Array interop for splatting into BoardState methods ---
  #
  # BoardState methods take (row, col) integer pairs. to_a lets callers
  # write board_contents.remove(*coord) without changing BoardState.

  test "to_a returns [row, col]" do
    assert_equal [2, 7], Coordinate.new(2, 7).to_a
  end

  test "splat into a (row, col) method works" do
    coord = Coordinate.new(2, 7)
    state = BoardState.new
    state.place_settlement(*coord, 0)
    assert_equal 0, state.player_at(2, 7)
  end

  # --- Value equality ---

  test "equal when row and col match" do
    assert_equal Coordinate.new(2, 7), Coordinate.new(2, 7)
  end

  test "not equal when row differs" do
    assert_not_equal Coordinate.new(2, 7), Coordinate.new(3, 7)
  end

  test "not equal when col differs" do
    assert_not_equal Coordinate.new(2, 7), Coordinate.new(2, 8)
  end

  test "not equal to plain array with same values" do
    assert_not_equal Coordinate.new(2, 7), [2, 7]
  end

  test "usable as a Hash key" do
    h = { Coordinate.new(2, 7) => :found }
    assert_equal :found, h[Coordinate.new(2, 7)]
    assert_nil h[Coordinate.new(2, 8)]
  end

  test "usable in Array#include?" do
    destinations = [Coordinate.new(1, 2), Coordinate.new(3, 4)]
    assert destinations.include?(Coordinate.new(1, 2))
    assert_not destinations.include?(Coordinate.new(9, 9))
  end
end
