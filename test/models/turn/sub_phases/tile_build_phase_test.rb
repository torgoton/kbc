require "test_helper"

class Turn::SubPhases::TileBuildPhaseTest < ActiveSupport::TestCase
  def setup
    @game = Game.create!(state: "waiting")
    @game.add_player(users(:chris))
    @game.add_player(users(:paula))
    @game.start
    @game.reload
    @game.instantiate
  end

  def phase(restricted_terrain: "G", tile_klass: "FarmTile", tile_source: Coordinate.new(0, 0))
    Turn::SubPhases::TileBuildPhase.new(
      restricted_terrain:, tile_klass:, tile_source:
    )
  end

  def first_empty_grass
    20.times do |row|
      20.times do |col|
        next unless @game.board.terrain_at(row, col) == "G"
        return [ row, col ] if @game.board_contents.empty?(row, col)
      end
    end
    raise "no empty grass hex on this board"
  end

  test "complete? is false on construction" do
    refute phase.complete?
  end

  test "to_h / from_h round-trip" do
    p = phase(tile_source: Coordinate.new(3, 4))
    rebuilt = Turn::SubPhases::TileBuildPhase.from_h(p.to_h)
    assert_equal "G", rebuilt.restricted_terrain
    assert_equal "FarmTile", rebuilt.tile_klass
    assert_equal Coordinate.new(3, 4), rebuilt.tile_source
  end

  test "handle(:build) on a Grass hex emits SettlementPlaced + TileConsumed and sets complete?" do
    row, col = first_empty_grass
    p = phase
    consequences = p.handle(:build, game: @game, player_order: 0, row:, col:)

    assert_kind_of Turn::Consequences::SettlementPlaced, consequences.first
    assert_equal Coordinate.new(row, col), consequences.first.at
    assert(consequences.any? { |c| c.is_a?(Turn::Consequences::TileConsumed) && c.klass == "FarmTile" })
    assert p.complete?
  end

  test "handle(:build) on a non-Grass hex emits Error and stays incomplete" do
    @game.instantiate
    spot = nil
    20.times do |row|
      20.times do |col|
        if @game.board.terrain_at(row, col) != "G" && @game.board_contents.empty?(row, col) && @game.board.terrain_at(row, col) != "L" && @game.board.terrain_at(row, col) != "S"
          spot = [ row, col ]
          break
        end
      end
      break if spot
    end
    raise "no non-grass empty hex" unless spot

    p = phase
    consequences = p.handle(:build, game: @game, player_order: 0, row: spot[0], col: spot[1])

    assert_equal 1, consequences.size
    assert_kind_of Turn::Consequences::Error, consequences.first
    refute p.complete?
  end

  test "handle(:build) on an occupied hex emits Error" do
    row, col = first_empty_grass
    @game.board_contents.place_settlement(row, col, 1)

    consequences = phase.handle(:build, game: @game, player_order: 0, row:, col:)
    assert_kind_of Turn::Consequences::Error, consequences.first
  end

  test "handle(:build) emits TilePickedUp for adjacent location with qty > 0" do
    row, col = first_empty_grass
    nr, nc = @game.board_contents.neighbors(row, col).first
    @game.board_contents.place_tile(nr, nc, "OracleTile", 2)

    consequences = phase.handle(:build, game: @game, player_order: 0, row:, col:)
    pickup = consequences.find { |c| c.is_a?(Turn::Consequences::TilePickedUp) }
    assert pickup, "expected TilePickedUp in consequences"
    assert_equal "OracleTile", pickup.klass
    assert_equal Coordinate.new(nr, nc), pickup.from
  end

  test "handle with unsupported action returns Error" do
    consequences = phase.handle(:nonsense, game: @game, player_order: 0)
    assert_kind_of Turn::Consequences::Error, consequences.first
  end
end
