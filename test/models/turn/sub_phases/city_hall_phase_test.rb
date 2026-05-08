require "test_helper"

class Turn::SubPhases::CityHallPhaseTest < ActiveSupport::TestCase
  def setup
    @game = Game.create!(state: "waiting")
    @game.add_player(users(:chris))
    @game.add_player(users(:paula))
    @game.start
    @game.reload
    @game.boards = [ [ 1, 0 ], [ 5, 0 ], [ 0, 0 ], [ 4, 0 ] ]
    @game.instantiate
    @player = @game.current_player
    @player.add_city_halls!(1)
    @player.save!
  end

  test "to_h round-trips through from_h" do
    rebuilt = Turn::SubPhases::CityHallPhase.from_h(Turn::SubPhases::CityHallPhase.new.to_h)

    assert_instance_of Turn::SubPhases::CityHallPhase, rebuilt
  end

  test "place_city_hall emits placement supply permanent tile and completes" do
    center = setup_city_hall_center
    phase = Turn::SubPhases::CityHallPhase.new

    cs = phase.handle(:place_city_hall, game: @game, player_order: @player.order, row: center[0], col: center[1])

    assert(cs.any? { |c| c.is_a?(Turn::Consequences::CityHallPlaced) })
    assert(cs.any? { |c| c.is_a?(Turn::Consequences::CityHallSupplyDecremented) })
    assert(cs.any? { |c| c.is_a?(Turn::Consequences::PermanentTileConsumed) && c.klass == "CityHallTile" })
    assert phase.complete?
  end

  test "place_city_hall rejects invalid center" do
    setup_city_hall_center

    cs = Turn::SubPhases::CityHallPhase.new.handle(:place_city_hall, game: @game, player_order: @player.order, row: 0, col: 0)

    assert_kind_of Turn::Consequences::Error, cs.first
  end

  test "place_city_hall rejects when supply is empty" do
    center = setup_city_hall_center
    @player.decrement_city_hall_supply!
    @player.save!

    cs = Turn::SubPhases::CityHallPhase.new.handle(:place_city_hall, game: @game, player_order: @player.order, row: center[0], col: center[1])

    assert_kind_of Turn::Consequences::Error, cs.first
  end

  private

  def setup_city_hall_center
    center = find_empty_cluster_center
    cluster = Set.new([ center ] + @game.board_contents.neighbors(*center))
    outer = @game.board_contents.neighbors(*center).lazy.flat_map { |row, col| @game.board_contents.neighbors(row, col) }
      .find { |hex| !cluster.include?(hex) && @game.board_contents.empty?(*hex) }
    raise "no outer settlement spot" unless outer

    @game.board_contents.place_settlement(*outer, @player.order)
    @game.save!
    center
  end

  def find_empty_cluster_center
    20.times do |row|
      20.times do |col|
        next unless Tiles::Tile::BUILDABLE_TERRAIN.include?(@game.board.terrain_at(row, col))
        next unless @game.board_contents.empty?(row, col)
        neighbors = @game.board_contents.neighbors(row, col)
        next unless neighbors.size == 6
        next unless neighbors.all? { |nr, nc|
          @game.board_contents.empty?(nr, nc) && Tiles::Tile::BUILDABLE_TERRAIN.include?(@game.board.terrain_at(nr, nc))
        }
        return [ row, col ]
      end
    end
    raise "no City Hall cluster center"
  end
end
