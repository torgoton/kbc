require "test_helper"

class TurnQuarryFlowTest < ActiveSupport::TestCase
  def setup
    @game = Game.create!(state: "waiting")
    @game.add_player(users(:chris))
    @game.add_player(users(:paula))
    @game.start
    @game.reload
    @game.instantiate
    @player = @game.current_player
  end

  test "activate Quarry, place one wall, end action, full unwind across 3 clicks" do
    terrain = @player.hand.first
    source, targets = first_quarry_setup(terrain)
    target = targets.first
    @game.board_contents.place_settlement(source[0], source[1], @player.order)
    @player.update!(tiles: [ { "klass" => "QuarryTile", "from" => "[5, 5]", "used" => false } ])
    @game.save!

    snapshot_before = snapshot

    cs = Turn.from_game(@game.reload).handle(:select_action, game: @game, tile: "QuarryTile")
    refute(cs.any? { |c| c.is_a?(Turn::Consequences::Error) }, "expected select_action to succeed: #{cs.inspect}")
    ConsequenceApplier.apply!(@game, cs)

    @game.reload
    assert_equal "wall_placement", @game.current_action.dig("turn", "sub_phase", "type")
    assert_equal 0, @game.current_action.dig("turn", "sub_phase", "state", "walls_placed")

    @game.instantiate
    cs = Turn.from_game(@game.reload).handle(:place_wall, game: @game, row: target[0], col: target[1])
    refute(cs.any? { |c| c.is_a?(Turn::Consequences::Error) }, "expected place_wall to succeed: #{cs.inspect}")
    ConsequenceApplier.apply!(@game, cs)

    @game.reload
    @game.instantiate
    assert_equal "Wall", @game.board_contents.tile_klass(target[0], target[1])
    assert_equal snapshot_before[:stone_walls] - 1, @game.stone_walls
    assert_equal 1, @game.current_action.dig("turn", "sub_phase", "state", "walls_placed")
    assert_equal terrain, @game.current_action.dig("turn", "sub_phase", "state", "chosen_terrain")

    cs = Turn.from_game(@game.reload).handle(:end_tile_action, game: @game)
    refute(cs.any? { |c| c.is_a?(Turn::Consequences::Error) }, "expected end_tile_action to succeed: #{cs.inspect}")
    ConsequenceApplier.apply!(@game, cs)

    @game.reload
    assert_nil @game.current_action.dig("turn", "sub_phase")
    assert @game.current_player.tiles.find { |t| t["klass"] == "QuarryTile" }["used"]

    3.times { ConsequenceApplier.unapply!(@game.reload) }
    assert_equal snapshot_before, snapshot
  end

  private

  def snapshot
    @game.reload
    {
      board_contents: BoardState.dump(@game.board_contents),
      current_action: @game.current_action.deep_dup,
      stone_walls: @game.stone_walls,
      players: @game.game_players.map { |g|
        g.reload
        { order: g.order, supply: g.supply.deep_dup, hand: Array(g.hand), tiles: g.tiles&.deep_dup, taken_from: g.taken_from&.dup }
      }
    }
  end

  def first_quarry_setup(terrain)
    20.times do |row|
      20.times do |col|
        next unless Tiles::Tile::BUILDABLE_TERRAIN.include?(@game.board.terrain_at(row, col))
        next unless @game.board_contents.empty?(row, col)
        targets = @game.board_contents.neighbors(row, col).select do |nr, nc|
          @game.board_contents.empty?(nr, nc) && @game.board.terrain_at(nr, nc) == terrain
        end
        return [ [ row, col ], targets ] if targets.size >= 2
      end
    end
    raise "no Quarry setup for #{terrain}"
  end
end
