require "test_helper"

# Nomad::DonationTile (and its 7 terrain variants) grants 3 extra settlement
# builds on the tile's donation terrain - adjacent to an existing settlement
# if possible, otherwise anywhere on that terrain - without consuming the
# mandatory build count. Unlike normal builds, donation tiles can build on
# terrain (water, mountain) that's otherwise off-limits.
class DonationTileTest < ActiveSupport::TestCase
  # [1,11] is Mountain with 4 Canyon (C) neighbors: [1,12],[0,11],[0,12],[2,12].
  ADJACENT_SETTLEMENT = [ 1, 11 ].freeze

  test "builds 3 settlements on the donation terrain adjacent to an existing settlement" do
    scenario = GameScenario.new
    scenario.place_settlement(0, at: ADJACENT_SETTLEMENT)
    scenario.give_tile(0, "Nomad::DonationCanyonTile", from: [ 0, 0 ])

    scenario.activate_tile(:"nomad::donationcanyon")

    3.times do |i|
      destinations = scenario.buildable_cells
      assert destinations.any?, "expected destinations on build #{i + 1}"
      destinations.each { |dest| assert_equal "C", scenario.terrain_at(dest) }
      target = destinations.first

      scenario.build_settlement(at: target)

      assert_equal 0, scenario.owner_at(target)
      assert_equal Game::SETTLEMENTS_PER_PLAYER - (i + 1), scenario.settlements_remaining(0)
      assert_equal Game::MANDATORY_COUNT, scenario.mandatory_remaining
      if i < 2
        assert_includes scenario.usable_tiles(0), "Nomad::DonationCanyonTile"
      else
        assert_not_includes scenario.usable_tiles(0), "Nomad::DonationCanyonTile"
      end
    end
  end

  test "builds anywhere on the donation terrain when no settlement is adjacent to one" do
    scenario = GameScenario.new
    scenario.give_tile(0, "Nomad::DonationCanyonTile", from: [ 0, 0 ])

    scenario.activate_tile(:"nomad::donationcanyon")

    3.times do |i|
      destinations = scenario.buildable_cells
      assert destinations.any?, "expected destinations on build #{i + 1}"
      destinations.each { |dest| assert_equal "C", scenario.terrain_at(dest) }
      target = destinations.first

      scenario.build_settlement(at: target)

      assert_equal 0, scenario.owner_at(target)
      assert_equal Game::SETTLEMENTS_PER_PLAYER - (i + 1), scenario.settlements_remaining(0)
    end

    assert_not_includes scenario.usable_tiles(0), "Nomad::DonationCanyonTile"
  end

  test "rejects a build on a different terrain than the donation terrain" do
    scenario = GameScenario.new
    scenario.give_tile(0, "Nomad::DonationCanyonTile", from: [ 0, 0 ])
    wrong_hex = scenario.empty_hexes("D", 1).first

    scenario.activate_tile(:"nomad::donationcanyon")

    assert_raises(GameScenario::IllegalMove) { scenario.build_settlement(at: wrong_hex) }
  end

  test "can build on terrain normally excluded from building (mountain)" do
    assert_not_includes Tiles::Tile::BUILDABLE_TERRAIN, "M"
    scenario = GameScenario.new
    scenario.give_tile(0, "Nomad::DonationMountainTile", from: [ 0, 0 ])

    scenario.activate_tile(:"nomad::donationmountain")

    3.times do |i|
      destinations = scenario.buildable_cells
      assert destinations.any?, "expected destinations on build #{i + 1}"
      destinations.each { |dest| assert_equal "M", scenario.terrain_at(dest) }
      target = destinations.first

      scenario.build_settlement(at: target)

      assert_equal 0, scenario.owner_at(target)
      assert_equal Game::SETTLEMENTS_PER_PLAYER - (i + 1), scenario.settlements_remaining(0)
    end

    assert_not_includes scenario.usable_tiles(0), "Nomad::DonationMountainTile"
  end
end
