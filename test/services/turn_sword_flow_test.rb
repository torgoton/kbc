require "test_helper"

class TurnSwordFlowTest < ActiveSupport::TestCase
  def setup
    @game = Game.create!(state: "waiting")
    @game.add_player(users(:chris))
    @game.add_player(users(:paula))
    @game.start
    @game.reload
    @game.instantiate
    @actor = @game.current_player
    @opponent = @game.game_players.find { |gp| gp.order != @actor.order }
  end

  test "activate Sword, remove opponent settlement, full unwind across 2 clicks" do
    target = first_buildable_hex
    @actor.update!(tiles: [ { "klass" => "SwordTile", "from" => "[5, 5]", "used" => false } ])
    @game.board_contents.place_settlement(target[0], target[1], @opponent.order)
    @game.save!

    snapshot_before = snapshot

    cs = Turn.from_game(@game.reload).handle(:select_action, game: @game, tile: "SwordTile")
    refute(cs.any? { |c| c.is_a?(Turn::Consequences::Error) }, "expected select_action to succeed: #{cs.inspect}")
    ConsequenceApplier.apply!(@game, cs)

    @game.reload
    assert_equal "targeted_removal", @game.current_action.dig("turn", "sub_phase", "type")
    assert_equal [ @opponent.order ], @game.current_action.dig("turn", "sub_phase", "state", "pending_orders")

    @game.instantiate
    before_supply = @opponent.reload.settlements_remaining
    cs = Turn.from_game(@game.reload).handle(:remove_settlement, game: @game, row: target[0], col: target[1])
    refute(cs.any? { |c| c.is_a?(Turn::Consequences::Error) }, "expected remove_settlement to succeed: #{cs.inspect}")
    ConsequenceApplier.apply!(@game, cs)

    @game.reload
    @game.instantiate
    assert_nil @game.board_contents.player_at(target[0], target[1])
    assert_equal before_supply + 1, @opponent.reload.settlements_remaining
    assert @game.current_player.tiles.find { |t| t["klass"] == "SwordTile" }["used"]
    assert_nil @game.current_action.dig("turn", "sub_phase")

    2.times { ConsequenceApplier.unapply!(@game.reload) }
    assert_equal snapshot_before, snapshot
  end

  test "remove_settlement on warrior restores warrior after unwind" do
    target = first_buildable_hex
    @actor.update!(tiles: [ { "klass" => "SwordTile", "from" => "[5, 5]", "used" => false } ])
    @opponent.add_warriors!(1)
    @game.board_contents.place_warrior(target[0], target[1], @opponent.order)
    @game.save!

    ConsequenceApplier.apply!(
      @game,
      Turn.from_game(@game.reload).handle(:select_action, game: @game, tile: "SwordTile")
    )
    @game.instantiate
    ConsequenceApplier.apply!(
      @game,
      Turn.from_game(@game.reload).handle(:remove_settlement, game: @game, row: target[0], col: target[1])
    )

    @game.reload
    @game.instantiate
    assert_nil @game.board_contents.player_at(target[0], target[1])

    ConsequenceApplier.unapply!(@game.reload)
    @game.reload
    @game.instantiate

    assert @game.board_contents.warrior_at?(target[0], target[1])
    assert_equal @opponent.order, @game.board_contents.player_at(target[0], target[1])
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

  def first_buildable_hex
    20.times do |row|
      20.times do |col|
        next unless Tiles::Tile::BUILDABLE_TERRAIN.include?(@game.board.terrain_at(row, col))
        return [ row, col ] if @game.board_contents.empty?(row, col)
      end
    end
    raise "no buildable hex"
  end
end
