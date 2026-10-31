require "test_helper"

# Scouts count as their owner's settlements for adjacency only. For each tile that measures
# "adjacent to your settlements", a Scout in place of the settlement must give the same
# destinations, and not the "anywhere" fallback that applies when nothing is adjacent.
class Tiles::ScoutAdjacencyTest < ActiveSupport::TestCase
  Terrain = Struct.new(:overrides, :default) do
    def terrain_at(row, col) = overrides.fetch([ row, col ], default)
  end

  HOME = [ 10, 10 ].freeze
  FAR = [ 3, 4 ].freeze # empty and nowhere near HOME

  def state(terrain, piece, extra = {})
    BoardState.new.tap do |s|
      s.terrain_source = terrain
      piece == :scout ? s.place_scout(*HOME, 0) : s.place_settlement(*HOME, 0)
      extra.each { |(r, c), owner| s.place_settlement(r, c, owner) }
    end
  end

  def assert_scout_acts_like_settlement(tile, terrain, extra: {}, **args)
    as_settlement = tile.valid_destinations(board_contents: state(terrain, :settlement, extra), player_order: 0, **args).sort
    as_scout = tile.valid_destinations(board_contents: state(terrain, :scout, extra), player_order: 0, **args).sort

    assert_not_empty as_settlement
    assert_equal as_settlement, as_scout
    assert_not_includes as_scout, FAR, "a scout must not fall back to anywhere"
  end

  test "Farmland" do
    assert_scout_acts_like_settlement(Tiles::Permanent::FarmlandTile.new(0), Terrain.new({}, "H"))
  end

  test "Water Mill, Mountain Station and University" do
    water = Terrain.new({ [ 10, 12 ] => "W", [ 3, 3 ] => "W" }, "G")
    assert_scout_acts_like_settlement(Tiles::Location::WaterMillTile.new(0), water)
    mountain = Terrain.new({ [ 10, 12 ] => "M", [ 3, 3 ] => "M" }, "G")
    assert_scout_acts_like_settlement(Tiles::Location::MountainStationTile.new(0), mountain)
    gold = Terrain.new({ [ 10, 12 ] => "L", [ 3, 3 ] => "L" }, "G")
    assert_scout_acts_like_settlement(Tiles::Location::UniversityTile.new(0), gold)
  end

  test "Watchtower" do
    assert_scout_acts_like_settlement(Tiles::Location::WatchtowerTile.new(0), Terrain.new({}, "G"),
      extra: { [ 10, 12 ] => 1, [ 3, 3 ] => 1 })
  end

  test "Tower" do
    assert_scout_acts_like_settlement(Tiles::Location::TowerTile.new(0), Terrain.new({}, "G"))
    edge = [ 0, 5 ]
    near = BoardState.new.tap { |s| s.terrain_source = Terrain.new({}, "G"); s.place_scout(*edge, 0) }
    assert_equal [ [ 0, 4 ], [ 0, 6 ] ], Tiles::Location::TowerTile.new(0).valid_destinations(board_contents: near, player_order: 0).sort
  end

  test "Donation" do
    assert_scout_acts_like_settlement(Tiles::Nomad::DonationGrassTile.new(0), Terrain.new({}, "G"))
  end

  test "Quarry" do
    assert_scout_acts_like_settlement(Tiles::Location::QuarryTile.new(0), Terrain.new({}, "G"), hand: "G")
  end

  test "Barracks" do
    assert_scout_acts_like_settlement(Tiles::Location::BarracksTile.new(0), Terrain.new({}, "G"), supply: { "warrior" => 1 })
  end

  test "Lighthouse and Wagon" do
    water = Terrain.new({ [ 10, 11 ] => "W", [ 3, 3 ] => "W" }, "G")
    assert_scout_acts_like_settlement(Tiles::Location::LighthouseTile.new(0), water, supply: { "ship" => 1 })
    assert_scout_acts_like_settlement(Tiles::Location::WagonTile.new(0), Terrain.new({}, "G"), supply: { "wagon" => 1 })
  end

  test "Harbor moves a settlement next to a scout's water, not anywhere" do
    water = Terrain.new({ [ 10, 11 ] => "W", [ 3, 3 ] => "W" }, "G")
    board = state(water, :scout, { [ 15, 15 ] => 0 })

    result = Tiles::Location::HarborTile.new(0).valid_destinations(from_row: 15, from_col: 15, board_contents: board, player_order: 0)

    assert_equal [ [ 10, 11 ] ], result
  end

  test "Village counts scouts among the 3 adjacent pieces" do
    target = [ 10, 10 ]
    board = BoardState.new.tap do |s|
      s.terrain_source = Terrain.new({}, "G")
      s.place_settlement(10, 9, 0)
      s.place_settlement(10, 11, 0)
      s.place_scout(9, 10, 0)
    end

    assert_includes Tiles::Location::VillageTile.new(0).valid_destinations(board_contents: board, player_order: 0), target
  end

  test "Tavern counts scouts in the line of 3" do
    board = BoardState.new.tap do |s|
      s.terrain_source = Terrain.new({}, "G")
      s.place_scout(10, 10, 0)
      s.place_settlement(10, 11, 0)
      s.place_settlement(10, 12, 0)
    end

    assert_equal [ [ 10, 9 ], [ 10, 13 ] ], Tiles::Location::TavernTile.new(0).valid_destinations(board_contents: board, player_order: 0).sort
  end

  test "Palisade moves a settlement next to a scout in its area, never onto a hex only the mover touches" do
    board = BoardState.new.tap do |s|
      s.terrain_source = Terrain.new({}, "G")
      s.place_settlement(10, 10, 0)
      s.place_scout(10, 11, 0)
    end

    result = Tiles::Location::PalisadeTile.new(0).valid_destinations(from_row: 10, from_col: 10, board_contents: board, player_order: 0)

    assert_includes result, [ 10, 12 ]
    assert_not_includes result, [ 10, 9 ], "touches only the mover itself"
  end
end
