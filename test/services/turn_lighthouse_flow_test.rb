require "test_helper"

class TurnLighthouseFlowTest < ActiveSupport::TestCase
  def setup
    @game = Game.create!(state: "waiting")
    @game.add_player(users(:chris))
    @game.add_player(users(:paula))
    @game.start
    @game.reload
    @game.instantiate
    @player = @game.current_player
    @player.update!(supply: { "settlements" => 40, "ships" => 1 })
  end

  test "activate Lighthouse, click own ship to set source, click destination to move; full unwind" do
    src = first_water_hex
    @game.board_contents.place_ship(src[0], src[1], @player.order)
    @player.update!(
      tiles: [ { "klass" => "LighthouseTile", "from" => "[2, 3]", "used" => false } ],
      supply: { "settlements" => 40, "ships" => 0 }
    )
    @game.save!

    instance = Tiles::LighthouseTile.new(0)
    dst = instance.valid_destinations(
      from_row: src[0], from_col: src[1],
      board_contents: @game.board_contents, board: @game.board, player_order: @player.order
    ).first
    refute_nil dst

    snapshot_before = snapshot

    # Click 1: activate Lighthouse.
    turn = Turn.from_game(@game.reload)
    @game.instantiate
    ConsequenceApplier.apply!(@game, turn.handle(:select_action, game: @game, tile: "LighthouseTile"))

    # Click 2: select ship as source.
    turn = Turn.from_game(@game.reload)
    @game.instantiate
    cs = turn.handle(:place_meeple, game: @game, row: src[0], col: src[1])
    refute(cs.any? { |c| c.is_a?(Turn::Consequences::Error) })
    ConsequenceApplier.apply!(@game, cs)

    @game.reload
    assert_equal "[#{src[0]}, #{src[1]}]", @game.current_action.dig("turn", "sub_phase", "state", "source")

    # Click 3: move ship.
    turn = Turn.from_game(@game.reload)
    @game.instantiate
    cs = turn.handle(:place_meeple, game: @game, row: dst[0], col: dst[1])
    refute(cs.any? { |c| c.is_a?(Turn::Consequences::Error) }, "expected move to succeed: #{cs.inspect}")
    ConsequenceApplier.apply!(@game, cs)

    @game.reload
    @game.instantiate
    assert_nil @game.board_contents.player_at(src[0], src[1])
    assert_equal @player.order, @game.board_contents.player_at(dst[0], dst[1])
    assert_equal "ship", @game.board_contents.meeple_at(dst[0], dst[1])
    assert_nil @game.current_action.dig("turn", "sub_phase")

    3.times { ConsequenceApplier.unapply!(@game.reload) }
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
          ships: g.ships_remaining,
          tiles: g.tiles&.deep_dup,
          taken_from: g.taken_from&.dup
        }
      }
    }
  end

  def first_water_hex
    20.times do |r|
      20.times do |c|
        return [ r, c ] if @game.board.terrain_at(r, c) == "W" && @game.board_contents.empty?(r, c)
      end
    end
    raise "no water hex"
  end
end
