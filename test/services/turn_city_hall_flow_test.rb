require "test_helper"

class TurnCityHallFlowTest < ActiveSupport::TestCase
  def setup
    @game = Game.create!(state: "waiting")
    @game.add_player(users(:chris))
    @game.add_player(users(:paula))
    @game.start
    @game.reload
    @game.boards = [ [ 1, 0 ], [ 5, 0 ], [ 0, 0 ], [ 4, 0 ] ]
    @game.instantiate
    @player = @game.current_player
  end

  test "activate City Hall, place cluster, full unwind across 2 clicks" do
    center = setup_city_hall
    snapshot_before = snapshot

    cs = Turn.from_game(@game.reload).handle(:select_action, game: @game, tile: "CityHallTile")
    refute(cs.any? { |c| c.is_a?(Turn::Consequences::Error) }, "expected select_action to succeed: #{cs.inspect}")
    ConsequenceApplier.apply!(@game, cs)

    @game.reload
    assert_equal "city_hall", @game.current_action.dig("turn", "sub_phase", "type")

    @game.instantiate
    cs = Turn.from_game(@game.reload).handle(:place_city_hall, game: @game, row: center[0], col: center[1])
    refute(cs.any? { |c| c.is_a?(Turn::Consequences::Error) }, "expected place_city_hall to succeed: #{cs.inspect}")
    ConsequenceApplier.apply!(@game, cs)

    @game.reload
    @game.instantiate
    cluster = [ center ] + @game.board_contents.neighbors(*center)
    cluster.each { |row, col| assert @game.board_contents.city_hall_at?(row, col), "expected City Hall at [#{row}, #{col}]" }
    assert_equal 0, @game.current_player.city_halls_remaining
    tile = @game.current_player.tiles.find { |t| t["klass"] == "CityHallTile" }
    assert tile["used"]
    assert tile["permanent"]
    assert_nil @game.current_action.dig("turn", "sub_phase")

    2.times { ConsequenceApplier.unapply!(@game.reload) }
    assert_equal snapshot_before, snapshot
  end

  private

  def snapshot
    @game.reload
    {
      board_contents: BoardState.dump(@game.board_contents),
      current_action: @game.current_action.deep_dup,
      players: @game.game_players.map { |g|
        g.reload
        { order: g.order, supply: g.supply.deep_dup, hand: Array(g.hand), tiles: g.tiles&.deep_dup, taken_from: g.taken_from&.dup }
      }
    }
  end

  def setup_city_hall
    @player.add_city_halls!(1)
    @player.tiles = [ { "klass" => "CityHallTile", "from" => "[2, 5]", "used" => false } ]
    center = find_empty_cluster_center
    cluster = Set.new([ center ] + @game.board_contents.neighbors(*center))
    outer = @game.board_contents.neighbors(*center).lazy.flat_map { |row, col| @game.board_contents.neighbors(row, col) }
      .find { |hex| !cluster.include?(hex) && @game.board_contents.empty?(*hex) }
    raise "no outer settlement spot" unless outer

    @game.board_contents.place_settlement(*outer, @player.order)
    @player.save!
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
