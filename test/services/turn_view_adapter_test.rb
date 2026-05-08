require "test_helper"

class TurnViewAdapterTest < ActiveSupport::TestCase
  def setup
    @game = Game.create!(state: "waiting")
    @game.add_player(users(:chris))
    @game.add_player(users(:paula))
    @game.start
    @game.reload
    @game.instantiate
    @player = @game.current_player
  end

  test "turn_state falls back to TurnEngine for legacy current_action" do
    @game.update!(current_action: { "type" => "mandatory" })

    assert_equal TurnEngine.new(@game).turn_state, TurnViewAdapter.new(@game).turn_state
  end

  test "mandatory Turn state exposes remaining count turn_state and buildable cells" do
    @player.update!(hand: [ "G" ])
    @game.update!(current_action: { "turn" => { "mandatory_remaining" => 2 } })

    adapter = TurnViewAdapter.new(@game)

    assert_equal 2, adapter.mandatory_remaining
    assert_match(/must build 2 settlements on Grass/, adapter.turn_state)
    assert(adapter.buildable_cells.any?)
  end

  test "tile_activatable uses Turn mandatory gate" do
    @game.update!(current_action: { "turn" => { "mandatory_remaining" => 1 } })
    tile = { "klass" => "OasisTile", "from" => "[2, 7]", "used" => false }

    assert_not TurnViewAdapter.new(@game).tile_activatable?(tile)

    @game.update!(current_action: { "turn" => { "mandatory_remaining" => 0 } })
    assert TurnViewAdapter.new(@game).tile_activatable?(tile)
  end

  test "settlement move phase exposes active tile type source and destinations" do
    src = first_paddock_source
    dst = Tiles::PaddockTile.new(0).valid_destinations(
      from_row: src[0], from_col: src[1],
      board_contents: @game.board_contents,
      board: @game.board,
      player_order: @player.order
    ).first
    @game.board_contents.place_settlement(src[0], src[1], @player.order)
    @player.update!(tiles: [ { "klass" => "PaddockTile", "from" => "[2, 3]", "used" => false } ])
    @game.update!(current_action: {
      "turn" => {
        "sub_phase" => {
          "type" => Turn::SubPhases::SettlementMovePhase::TYPE,
          "state" => { "tile_klass" => "PaddockTile", "source" => "[#{src[0]}, #{src[1]}]" }
        }
      }
    })

    adapter = TurnViewAdapter.new(@game)

    assert_equal "paddock", adapter.current_action_type
    assert_equal "[#{src[0]}, #{src[1]}]", adapter.current_action_from
    assert_includes adapter.buildable_cells, dst
  end

  test "tile_action_endable is true for started wall placement phase" do
    @game.update!(current_action: {
      "turn" => {
        "sub_phase" => {
          "type" => Turn::SubPhases::WallPlacementPhase::TYPE,
          "state" => { "walls_placed" => 1, "chosen_terrain" => "G" }
        }
      }
    })

    assert TurnViewAdapter.new(@game).tile_action_endable?
  end

  test "city_hall_clusters returns center keyed cluster for Turn City Hall phase" do
    center = setup_city_hall
    @game.update!(current_action: {
      "turn" => {
        "sub_phase" => {
          "type" => Turn::SubPhases::CityHallPhase::TYPE,
          "state" => {}
        }
      }
    })

    clusters = TurnViewAdapter.new(@game).city_hall_clusters

    assert_includes clusters.keys, "#{center[0]},#{center[1]}"
    assert_equal 7, clusters["#{center[0]},#{center[1]}"].size
  end

  test "undo_allowed reads TurnClick when present" do
    TurnClick.create!(game: @game, order: 1, consequences: [], reversible: false)
    TurnClick.create!(game: @game, order: 2, consequences: [], reversible: true)
    @game.update!(current_action: { "turn" => { "mandatory_remaining" => 3 } })

    assert TurnViewAdapter.new(@game).undo_allowed?
  end

  private

  def first_paddock_source
    20.times do |row|
      20.times do |col|
        next if @game.board.terrain_at(row, col).nil?
        next unless @game.board_contents.empty?(row, col)
        next unless Tiles::PaddockTile.new(0).valid_destinations(
          from_row: row, from_col: col,
          board_contents: @game.board_contents,
          board: @game.board,
          player_order: @player.order
        ).any?
        return [ row, col ]
      end
    end
    raise "no Paddock source"
  end

  def setup_city_hall
    @game.boards = [ [ 1, 0 ], [ 5, 0 ], [ 0, 0 ], [ 4, 0 ] ]
    @game.board_contents = BoardState.new
    @game.save!
    @game.reload
    @game.instantiate
    @player = @game.current_player
    @player.add_city_halls!(1)
    @player.save!

    center = find_city_hall_center
    cluster = Set.new([ center ] + @game.board_contents.neighbors(*center))
    outer = @game.board_contents.neighbors(*center).lazy.flat_map { |row, col| @game.board_contents.neighbors(row, col) }
      .find { |hex| !cluster.include?(hex) && @game.board_contents.empty?(*hex) }
    @game.board_contents.place_settlement(*outer, @player.order)
    @game.save!
    center
  end

  def find_city_hall_center
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
    raise "no City Hall center"
  end
end
