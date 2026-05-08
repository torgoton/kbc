require "test_helper"

class TurnVillageFlowTest < ActiveSupport::TestCase
  def setup
    @game = Game.create!(state: "waiting")
    @game.add_player(users(:chris))
    @game.add_player(users(:paula))
    @game.start
    @game.reload
    @game.instantiate
    @player = @game.current_player
  end

  test "activate Village tile, build adjacent to 3+ own settlements, full unwind" do
    cluster = three_clustered_grass_with_common_neighbor
    cluster[:settlements].each { |r, c| @game.board_contents.place_settlement(r, c, @player.order) }
    @player.update!(tiles: [ { "klass" => "VillageTile", "from" => "[2, 3]", "used" => false } ])
    @game.save!

    target = cluster[:target]
    snapshot_before = snapshot

    # Click 1: activate Village.
    turn = Turn.from_game(@game.reload)
    @game.instantiate
    cs = turn.handle(:select_action, game: @game, tile: "VillageTile")
    refute(cs.any? { |c| c.is_a?(Turn::Consequences::Error) })
    ConsequenceApplier.apply!(@game, cs)

    @game.reload
    assert_equal "tile_build", @game.current_action.dig("turn", "sub_phase", "type")
    assert_nil @game.current_action.dig("turn", "sub_phase", "state", "restricted_terrain")

    # Click 2: build at the cluster-adjacent target.
    turn = Turn.from_game(@game.reload)
    @game.instantiate
    cs = turn.handle(:build, game: @game, row: target[0], col: target[1])
    refute(cs.any? { |c| c.is_a?(Turn::Consequences::Error) }, "expected build success at #{target.inspect}")
    ConsequenceApplier.apply!(@game, cs)

    @game.reload
    @game.instantiate
    assert_equal @player.order, @game.board_contents.player_at(target[0], target[1])

    2.times { ConsequenceApplier.unapply!(@game.reload) }
    assert_equal snapshot_before, snapshot
  end

  test "Village build at a hex NOT adjacent to 3+ settlements errors" do
    @player.update!(tiles: [ { "klass" => "VillageTile", "from" => "[2, 3]", "used" => false } ])
    turn = Turn.from_game(@game.reload)
    @game.instantiate
    ConsequenceApplier.apply!(@game, turn.handle(:select_action, game: @game, tile: "VillageTile"))

    turn = Turn.from_game(@game.reload)
    @game.instantiate
    cs = turn.handle(:build, game: @game, row: 5, col: 5)  # no settlements anywhere yet
    assert_kind_of Turn::Consequences::Error, cs.first
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

  def three_clustered_grass_with_common_neighbor
    20.times do |r|
      20.times do |c|
        next unless @game.board.terrain_at(r, c) == "G"
        next unless @game.board_contents.empty?(r, c)
        nbrs = @game.board_contents.neighbors(r, c).select { |nr, nc|
          @game.board.terrain_at(nr, nc) == "G" && @game.board_contents.empty?(nr, nc)
        }
        next if nbrs.size < 3
        return { target: [ r, c ], settlements: nbrs.first(3) }
      end
    end
    raise "no Village-eligible cluster on this board"
  end
end
