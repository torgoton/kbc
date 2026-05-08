require "test_helper"

class TurnResettlementFlowTest < ActiveSupport::TestCase
  def setup
    @game = Game.create!(state: "waiting")
    @game.add_player(users(:chris))
    @game.add_player(users(:paula))
    @game.start
    @game.reload
    @game.boards = [ [ 10, 0 ], [ 5, 0 ], [ 0, 0 ], [ 4, 0 ] ]
    @game.instantiate
    @player = @game.current_player
  end

  test "activate Resettlement, select source, move, end action, full unwind across 4 clicks" do
    src = [ 0, 0 ]
    dst = [ 0, 2 ]
    @game.board_contents.place_settlement(src[0], src[1], @player.order)
    @player.update!(tiles: [ { "klass" => "ResettlementTile", "from" => "[5, 5]", "used" => false } ])
    @game.save!

    snapshot_before = snapshot

    cs = Turn.from_game(@game.reload).handle(:select_action, game: @game, tile: "ResettlementTile")
    refute(cs.any? { |c| c.is_a?(Turn::Consequences::Error) }, "expected select_action to succeed: #{cs.inspect}")
    ConsequenceApplier.apply!(@game, cs)

    @game.reload
    assert_equal "resettlement", @game.current_action.dig("turn", "sub_phase", "type")
    assert_equal 4, @game.current_action.dig("turn", "sub_phase", "state", "budget")
    assert_equal [], @game.current_action.dig("turn", "sub_phase", "state", "vacated")
    assert_equal 0, @game.current_action.dig("turn", "sub_phase", "state", "moves")

    @game.instantiate
    cs = Turn.from_game(@game.reload).handle(:select_settlement, game: @game, row: src[0], col: src[1])
    refute(cs.any? { |c| c.is_a?(Turn::Consequences::Error) }, "expected select_settlement to succeed: #{cs.inspect}")
    ConsequenceApplier.apply!(@game, cs)

    @game.reload
    assert_equal "[#{src[0]}, #{src[1]}]", @game.current_action.dig("turn", "sub_phase", "state", "source")

    @game.instantiate
    cs = Turn.from_game(@game.reload).handle(:move_settlement, game: @game, row: dst[0], col: dst[1])
    refute(cs.any? { |c| c.is_a?(Turn::Consequences::Error) }, "expected move_settlement to succeed: #{cs.inspect}")
    ConsequenceApplier.apply!(@game, cs)

    @game.reload
    @game.instantiate
    assert_nil @game.board_contents.player_at(src[0], src[1])
    assert_equal @player.order, @game.board_contents.player_at(dst[0], dst[1])
    assert_equal 2, @game.current_action.dig("turn", "sub_phase", "state", "budget")
    assert_equal [ "[#{src[0]}, #{src[1]}]" ], @game.current_action.dig("turn", "sub_phase", "state", "vacated")
    assert_equal 1, @game.current_action.dig("turn", "sub_phase", "state", "moves")
    assert_nil @game.current_action.dig("turn", "sub_phase", "state", "source")

    cs = Turn.from_game(@game.reload).handle(:end_tile_action, game: @game)
    refute(cs.any? { |c| c.is_a?(Turn::Consequences::Error) }, "expected end_tile_action to succeed: #{cs.inspect}")
    ConsequenceApplier.apply!(@game, cs)

    @game.reload
    assert_nil @game.current_action.dig("turn", "sub_phase")
    assert @game.current_player.tiles.find { |t| t["klass"] == "ResettlementTile" }["used"]

    4.times { ConsequenceApplier.unapply!(@game.reload) }
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
end
