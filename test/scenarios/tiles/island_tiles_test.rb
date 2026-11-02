require "test_helper"

# Rope Bridge and Tree House (the Island's locations) each grant one extra settlement move to a
# fixed terrain - canyon and timberland - adjacent to another of the player's settlements if
# possible, otherwise anywhere on that terrain.
class IslandTilesTest < ActiveSupport::TestCase
  { "RopeBridgeTile" => "C", "TreeHouseTile" => "T" }.each do |klass, terrain|
    test "#{klass} moves a settlement to #{terrain}, adjacent to another settlement when possible" do
      scenario = GameScenario.new
      moving_spot = [ 10, 10 ]
      scenario.place_settlement(0, at: moving_spot)
      anchor = (0..19).flat_map { |r| (0..19).map { |c| [ r, c ] } }.find do |spot|
        scenario.terrain_at(spot) != terrain && scenario.neighbors(spot).any? { |n| scenario.terrain_at(n) == terrain } && spot != moving_spot
      end
      scenario.place_settlement(0, at: anchor)
      scenario.give_tile(0, klass, from: [ 0, 0 ])

      scenario.activate_tile(klass.delete_suffix("Tile").downcase.to_sym)
      scenario.select_settlement(at: moving_spot)
      destinations = scenario.buildable_cells

      assert destinations.any?
      destinations.each do |dest|
        assert_equal terrain, scenario.terrain_at(dest)
        assert_includes scenario.neighbors(anchor), dest
      end

      scenario.move_step(to: destinations.first)
      assert_equal 0, scenario.owner_at(destinations.first)
      assert_nil scenario.owner_at(moving_spot)
      assert_not_includes scenario.usable_tiles(0), klass
    end

    test "#{klass} moves anywhere on #{terrain} when no other settlement is adjacent to one" do
      scenario = GameScenario.new
      moving_spot = [ 10, 10 ]
      scenario.place_settlement(0, at: moving_spot)
      scenario.give_tile(0, klass, from: [ 0, 0 ])

      scenario.activate_tile(klass.delete_suffix("Tile").downcase.to_sym)
      scenario.select_settlement(at: moving_spot)
      destinations = scenario.buildable_cells

      assert destinations.any?
      destinations.each { |dest| assert_equal terrain, scenario.terrain_at(dest) }
    end
  end
end
