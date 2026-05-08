require "test_helper"

class TurnPaddockFlowTest < ActiveSupport::TestCase
  def setup
    @game = Game.create!(state: "waiting")
    @game.add_player(users(:chris))
    @game.add_player(users(:paula))
    @game.start
    @game.reload
    @game.instantiate
    @player = @game.current_player
  end

  test "activate Paddock, select source, move destination, full unwind across 3 clicks" do
    src = first_paddock_movable_source
    dst = paddock_destination_for(src)

    @game.board_contents.place_settlement(src[0], src[1], @player.order)
    @player.update!(tiles: [ { "klass" => "PaddockTile", "from" => "[2, 3]", "used" => false } ])
    @game.save!

    snapshot_before = snapshot

    # Click 1: activate Paddock.
    turn = Turn.from_game(@game.reload)
    @game.instantiate
    cs = turn.handle(:select_action, game: @game, tile: "PaddockTile")
    refute(cs.any? { |c| c.is_a?(Turn::Consequences::Error) })
    ConsequenceApplier.apply!(@game, cs)

    @game.reload
    assert_equal "settlement_move", @game.current_action.dig("turn", "sub_phase", "type")
    assert_nil @game.current_action.dig("turn", "sub_phase", "state", "source")

    # Click 2: select source.
    turn = Turn.from_game(@game.reload)
    @game.instantiate
    cs = turn.handle(:select_settlement, game: @game, row: src[0], col: src[1])
    refute(cs.any? { |c| c.is_a?(Turn::Consequences::Error) })
    ConsequenceApplier.apply!(@game, cs)

    @game.reload
    assert_equal "[#{src[0]}, #{src[1]}]", @game.current_action.dig("turn", "sub_phase", "state", "source")

    # Click 3: move to destination.
    turn = Turn.from_game(@game.reload)
    @game.instantiate
    cs = turn.handle(:move_settlement, game: @game, row: dst[0], col: dst[1])
    refute(cs.any? { |c| c.is_a?(Turn::Consequences::Error) }, "expected move_settlement to succeed: #{cs.inspect}")
    ConsequenceApplier.apply!(@game, cs)

    @game.reload
    @game.instantiate
    assert_nil @game.board_contents.player_at(src[0], src[1])
    assert_equal @player.order, @game.board_contents.player_at(dst[0], dst[1])
    assert_nil @game.current_action.dig("turn", "sub_phase")

    # Three unapply calls roll all the way back.
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
        { order: g.order, supply: g.settlements_remaining, tiles: g.tiles&.deep_dup, taken_from: g.taken_from&.dup }
      }
    }
  end

  def first_paddock_movable_source
    20.times do |r|
      20.times do |c|
        next if @game.board.terrain_at(r, c).nil?
        next unless @game.board_contents.empty?(r, c)
        instance = Tiles::PaddockTile.new(0)
        next unless instance.valid_destinations(from_row: r, from_col: c, board_contents: @game.board_contents, board: @game.board, player_order: 0).any?
        return [ r, c ]
      end
    end
    raise "no Paddock-movable source on this board"
  end

  def paddock_destination_for(src)
    Tiles::PaddockTile.new(0).valid_destinations(
      from_row: src[0], from_col: src[1],
      board_contents: @game.board_contents, board: @game.board, player_order: 0
    ).first
  end
end
