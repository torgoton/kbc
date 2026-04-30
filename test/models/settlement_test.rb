require "test_helper"

class SettlementTest < ActiveSupport::TestCase
  test "player is set" do
    assert_equal 2, Settlement.new(2).player
  end

  test "meeple_type defaults to nil" do
    assert_nil Settlement.new(0).meeple_type
  end

  test "meeple_type can be set" do
    assert_equal "warrior", Settlement.new(0, meeple_type: "warrior").meeple_type
  end

  test "warrior? is true when meeple_type is warrior" do
    assert Settlement.new(0, meeple_type: "warrior").warrior?
  end

  test "warrior? is false for regular settlement" do
    assert_not Settlement.new(0).warrior?
  end

  test "ship? is true when meeple_type is ship" do
    assert Settlement.new(0, meeple_type: "ship").ship?
  end

  test "ship? is false for regular settlement" do
    assert_not Settlement.new(0).ship?
  end

  test "ship? is false for warrior" do
    assert_not Settlement.new(0, meeple_type: "warrior").ship?
  end

  test "city_hall? defaults to false" do
    assert_not Settlement.new(0).city_hall?
  end

  test "city_hall? is true when constructed with city_hall: true" do
    assert Settlement.new(0, city_hall: true).city_hall?
  end
end
