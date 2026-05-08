require "test_helper"

class TurnBarracksFlowTest < ActiveSupport::TestCase
  def setup
    @game = Game.create!(state: "waiting")
    @game.add_player(users(:chris))
    @game.add_player(users(:paula))
    @game.start
    @game.reload
    @game.instantiate
    @player = @game.current_player
    @player.update!(supply: { "settlements" => 40, "warriors" => 2 })
  end

  test "activate Barracks on own warrior removes it (full E2E + unwind)" do
    target = first_buildable_hex
    @game.board_contents.place_warrior(target[0], target[1], @player.order)
    @player.update!(
      tiles: [ { "klass" => "BarracksTile", "from" => "[2, 3]", "used" => false } ],
      supply: { "settlements" => 40, "warriors" => 0 }  # warrior is on the board
    )
    @game.save!

    snapshot_before = snapshot

    turn = Turn.from_game(@game.reload)
    @game.instantiate
    ConsequenceApplier.apply!(@game, turn.handle(:select_action, game: @game, tile: "BarracksTile"))

    turn = Turn.from_game(@game.reload)
    @game.instantiate
    cs = turn.handle(:place_meeple, game: @game, row: target[0], col: target[1])
    refute(cs.any? { |c| c.is_a?(Turn::Consequences::Error) })
    ConsequenceApplier.apply!(@game, cs)

    @game.reload
    @game.instantiate
    assert_nil @game.board_contents.player_at(target[0], target[1])
    @player.reload
    assert_equal 1, @player.warriors_remaining

    2.times { ConsequenceApplier.unapply!(@game.reload) }
    assert_equal snapshot_before, snapshot
  end

  test "activate Barracks, place warrior, full unwind" do
    @player.update!(tiles: [ { "klass" => "BarracksTile", "from" => "[2, 3]", "used" => false } ])
    snapshot_before = snapshot

    # Click 1: activate Barracks.
    turn = Turn.from_game(@game.reload)
    @game.instantiate
    cs = turn.handle(:select_action, game: @game, tile: "BarracksTile")
    refute(cs.any? { |c| c.is_a?(Turn::Consequences::Error) })
    ConsequenceApplier.apply!(@game, cs)

    @game.reload
    assert_equal "meeple_placement", @game.current_action.dig("turn", "sub_phase", "type")

    # Click 2: place warrior at a buildable hex.
    target = first_buildable_hex
    turn = Turn.from_game(@game.reload)
    @game.instantiate
    cs = turn.handle(:place_meeple, game: @game, row: target[0], col: target[1])
    refute(cs.any? { |c| c.is_a?(Turn::Consequences::Error) })
    ConsequenceApplier.apply!(@game, cs)

    @game.reload
    @game.instantiate
    assert_equal "warrior", @game.board_contents.meeple_at(target[0], target[1])
    assert_equal @player.order, @game.board_contents.player_at(target[0], target[1])
    assert_nil @game.current_action.dig("turn", "sub_phase")
    @player.reload
    assert_equal 1, @player.warriors_remaining

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
        {
          order: g.order,
          settlements: g.settlements_remaining,
          warriors: g.warriors_remaining,
          tiles: g.tiles&.deep_dup,
          taken_from: g.taken_from&.dup
        }
      }
    }
  end

  def first_buildable_hex
    20.times do |r|
      20.times do |c|
        next unless [ "C", "D", "F", "G", "T" ].include?(@game.board.terrain_at(r, c))
        return [ r, c ] if @game.board_contents.empty?(r, c)
      end
    end
    raise "no buildable hex"
  end
end
