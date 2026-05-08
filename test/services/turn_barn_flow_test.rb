require "test_helper"

class TurnBarnFlowTest < ActiveSupport::TestCase
  def setup
    @game = Game.create!(state: "waiting")
    @game.add_player(users(:chris))
    @game.add_player(users(:paula))
    @game.start
    @game.reload
    @game.boards = [ [ 6, 0 ], [ 5, 0 ], [ 0, 0 ], [ 4, 0 ] ]
    @game.instantiate
    @player = @game.current_player
  end

  test "activate Barn, select source, move to played terrain, full unwind across 3 clicks" do
    src = [ 0, 0 ]
    @player.update!(
      hand: [ "F" ],
      tiles: [ { "klass" => "BarnTile", "from" => "[2, 6]", "used" => false } ]
    )
    @game.board_contents.place_settlement(src[0], src[1], @player.order)
    @game.save!
    dst = barn_destination_for(src)

    snapshot_before = snapshot

    cs = Turn.from_game(@game.reload).handle(:select_action, game: @game, tile: "BarnTile")
    refute(cs.any? { |c| c.is_a?(Turn::Consequences::Error) }, "expected select_action to succeed: #{cs.inspect}")
    ConsequenceApplier.apply!(@game, cs)

    @game.reload
    assert_equal "settlement_move", @game.current_action.dig("turn", "sub_phase", "type")
    assert_nil @game.current_action.dig("turn", "sub_phase", "state", "source")

    @game.instantiate
    cs = Turn.from_game(@game.reload).handle(:select_settlement, game: @game, row: src[0], col: src[1])
    refute(cs.any? { |c| c.is_a?(Turn::Consequences::Error) }, "expected select_settlement to succeed: #{cs.inspect}")
    ConsequenceApplier.apply!(@game, cs)

    @game.instantiate
    cs = Turn.from_game(@game.reload).handle(:move_settlement, game: @game, row: dst[0], col: dst[1])
    refute(cs.any? { |c| c.is_a?(Turn::Consequences::Error) }, "expected move_settlement to succeed: #{cs.inspect}")
    ConsequenceApplier.apply!(@game, cs)

    @game.reload
    @game.instantiate
    assert_nil @game.board_contents.player_at(src[0], src[1])
    assert_equal @player.order, @game.board_contents.player_at(dst[0], dst[1])
    assert @game.current_player.tiles.find { |t| t["klass"] == "BarnTile" }["used"]

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
        { order: g.order, supply: g.supply.deep_dup, hand: Array(g.hand), tiles: g.tiles&.deep_dup, taken_from: g.taken_from&.dup }
      }
    }
  end

  def barn_destination_for(src)
    Tiles::BarnTile.new(0).valid_destinations(
      from_row: src[0], from_col: src[1],
      board_contents: @game.board_contents,
      board: @game.board,
      player_order: @player.order,
      hand: @player.hand.first
    ).first || raise("no Barn destination")
  end
end
