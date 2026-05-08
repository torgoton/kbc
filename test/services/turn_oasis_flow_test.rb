require "test_helper"

class TurnOasisFlowTest < ActiveSupport::TestCase
  def setup
    @game = Game.create!(state: "waiting")
    @game.add_player(users(:chris))
    @game.add_player(users(:paula))
    @game.start
    @game.reload
    @game.instantiate
    @player = @game.current_player
  end

  test "activate Oasis tile, build on Desert, undo back to start" do
    @player.update!(tiles: [ { "klass" => "OasisTile", "from" => "[2, 3]", "used" => false } ])
    target = first_empty_terrain("D")

    snapshot_before = snapshot

    # Click 1: activate Oasis.
    turn = Turn.from_game(@game.reload)
    @game.instantiate
    cs = turn.handle(:select_action, game: @game, tile: "OasisTile")
    ConsequenceApplier.apply!(@game, cs)

    @game.reload
    assert_equal "tile_build", @game.current_action.dig("turn", "sub_phase", "type")
    assert_equal "D", @game.current_action.dig("turn", "sub_phase", "state", "restricted_terrain")
    assert_equal "OasisTile", @game.current_action.dig("turn", "sub_phase", "state", "tile_klass")

    # Click 2: build at the Desert hex.
    turn = Turn.from_game(@game.reload)
    @game.instantiate
    cs = turn.handle(:build, game: @game, row: target[0], col: target[1])
    refute(cs.any? { |c| c.is_a?(Turn::Consequences::Error) })
    ConsequenceApplier.apply!(@game, cs)

    @game.reload
    @game.instantiate
    assert_equal 0, @game.board_contents.player_at(target[0], target[1])

    # Two clicks → two unwind calls back to the starting snapshot.
    2.times { ConsequenceApplier.unapply!(@game.reload) }

    assert_equal snapshot_before, snapshot
    assert_equal 0, TurnClick.where(game: @game).count
  end

  private

  def snapshot
    @game.reload
    {
      board_contents: BoardState.dump(@game.board_contents),
      current_action: @game.current_action.deep_dup,
      players: @game.game_players.map { |g|
        g.reload
        { order: g.order, supply: g.settlements_remaining, tiles: g.tiles&.deep_dup, taken_from: g.taken_from&.dup }
      }
    }
  end

  def first_empty_terrain(terrain)
    20.times do |r|
      20.times do |c|
        return [ r, c ] if @game.board.terrain_at(r, c) == terrain && @game.board_contents.empty?(r, c)
      end
    end
    raise "no empty #{terrain}"
  end
end
