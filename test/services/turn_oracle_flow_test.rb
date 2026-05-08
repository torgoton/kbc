require "test_helper"

class TurnOracleFlowTest < ActiveSupport::TestCase
  def setup
    @game = Game.create!(state: "waiting")
    @game.add_player(users(:chris))
    @game.add_player(users(:paula))
    @game.start
    @game.reload
    @game.instantiate
    @player = @game.current_player
    @hand_terrain = @player.hand.first
  end

  test "activate Oracle, build on a hex of hand-terrain, full unwind" do
    @player.update!(tiles: [ { "klass" => "OracleTile", "from" => "[2, 3]", "used" => false } ])
    target = first_empty_terrain(@hand_terrain)
    snapshot_before = snapshot

    turn = Turn.from_game(@game.reload)
    @game.instantiate
    cs = turn.handle(:select_action, game: @game, tile: "OracleTile")
    refute(cs.any? { |c| c.is_a?(Turn::Consequences::Error) })
    ConsequenceApplier.apply!(@game, cs)

    @game.reload
    assert_equal "tile_build", @game.current_action.dig("turn", "sub_phase", "type")
    assert_nil @game.current_action.dig("turn", "sub_phase", "state", "restricted_terrain")
    assert_equal "OracleTile", @game.current_action.dig("turn", "sub_phase", "state", "tile_klass")

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

  test "Oracle build on a non-hand-terrain hex errors" do
    @player.update!(tiles: [ { "klass" => "OracleTile", "from" => "[2, 3]", "used" => false } ])
    different_terrain_hex = first_empty_terrain_other_than(@hand_terrain)

    turn = Turn.from_game(@game.reload)
    @game.instantiate
    ConsequenceApplier.apply!(@game, turn.handle(:select_action, game: @game, tile: "OracleTile"))

    turn = Turn.from_game(@game.reload)
    @game.instantiate
    cs = turn.handle(:build, game: @game, row: different_terrain_hex[0], col: different_terrain_hex[1])
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

  def first_empty_terrain(terrain)
    20.times do |r|
      20.times do |c|
        return [ r, c ] if @game.board.terrain_at(r, c) == terrain && @game.board_contents.empty?(r, c)
      end
    end
    raise "no empty #{terrain}"
  end

  def first_empty_terrain_other_than(terrain)
    20.times do |r|
      20.times do |c|
        t = @game.board.terrain_at(r, c)
        next if t.nil? || t == terrain
        return [ r, c ] if @game.board_contents.empty?(r, c)
      end
    end
    raise "no empty non-#{terrain} hex"
  end
end
