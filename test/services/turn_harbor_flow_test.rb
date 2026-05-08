require "test_helper"

class TurnHarborFlowTest < ActiveSupport::TestCase
  def setup
    @game = Game.create!(state: "waiting")
    @game.add_player(users(:chris))
    @game.add_player(users(:paula))
    @game.start
    @game.reload
    @game.instantiate
    @player = @game.current_player
  end

  test "activate Harbor, select source, move to water, full unwind across 3 clicks" do
    src = first_harbor_source
    @game.board_contents.place_settlement(src[0], src[1], @player.order)
    @player.update!(tiles: [ { "klass" => "HarborTile", "from" => "[2, 3]", "used" => false } ])
    @game.save!
    dst = harbor_destination_for(src)

    snapshot_before = snapshot

    cs = Turn.from_game(@game.reload).handle(:select_action, game: @game, tile: "HarborTile")
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
    assert @game.current_player.tiles.find { |t| t["klass"] == "HarborTile" }["used"]
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
        { order: g.order, supply: g.supply.deep_dup, hand: Array(g.hand), tiles: g.tiles&.deep_dup, taken_from: g.taken_from&.dup }
      }
    }
  end

  def first_harbor_source
    20.times do |r|
      20.times do |c|
        next unless Tiles::Tile::BUILDABLE_TERRAIN.include?(@game.board.terrain_at(r, c))
        next unless @game.board_contents.empty?(r, c)
        return [ r, c ]
      end
    end
    raise "no Harbor source on this board"
  end

  def harbor_destination_for(src)
    Tiles::HarborTile.new(0).valid_destinations(
      from_row: src[0], from_col: src[1],
      board_contents: @game.board_contents,
      board: @game.board,
      player_order: @player.order
    ).first || raise("no Harbor destination")
  end
end
