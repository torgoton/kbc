require "test_helper"

class Turn::SubPhases::TargetedRemovalPhaseTest < ActiveSupport::TestCase
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

  test "to_h round-trips through from_h" do
    phase = Turn::SubPhases::TargetedRemovalPhase.new(pending_orders: [ 1, 2 ])

    rebuilt = Turn::SubPhases::TargetedRemovalPhase.from_h(phase.to_h)

    assert_equal [ 1, 2 ], rebuilt.pending_orders
  end

  test "remove_settlement removes target owner from pending orders when more remain" do
    @game.board_contents.place_settlement(4, 4, @opponent.order)
    phase = Turn::SubPhases::TargetedRemovalPhase.new(pending_orders: [ @opponent.order, 2 ])

    cs = phase.handle(:remove_settlement, game: @game, player_order: @actor.order, row: 4, col: 4)

    removed = cs.find { |c| c.is_a?(Turn::Consequences::PieceRemoved) }
    update = cs.find { |c| c.is_a?(Turn::Consequences::SubPhaseStateUpdated) }
    refute_nil removed
    assert_equal @opponent.order, removed.player
    assert_equal [ 2 ], update.new_state["pending_orders"]
    refute phase.complete?
  end

  test "remove_settlement consumes tile and completes after last pending owner" do
    @game.board_contents.place_settlement(4, 4, @opponent.order)
    phase = Turn::SubPhases::TargetedRemovalPhase.new(pending_orders: [ @opponent.order ])

    cs = phase.handle(:remove_settlement, game: @game, player_order: @actor.order, row: 4, col: 4)

    assert(cs.any? { |c| c.is_a?(Turn::Consequences::PieceRemoved) })
    assert(cs.any? { |c| c.is_a?(Turn::Consequences::TileConsumed) && c.klass == "SwordTile" && c.player == @actor.order })
    assert phase.complete?
  end

  test "remove_settlement rejects city hall hex" do
    @game.board_contents.place_city_hall_hex(4, 4, @opponent.order)
    phase = Turn::SubPhases::TargetedRemovalPhase.new(pending_orders: [ @opponent.order ])

    cs = phase.handle(:remove_settlement, game: @game, player_order: @actor.order, row: 4, col: 4)

    assert_kind_of Turn::Consequences::Error, cs.first
  end

  test "remove_settlement rejects owner not pending" do
    @game.board_contents.place_settlement(4, 4, @opponent.order)
    phase = Turn::SubPhases::TargetedRemovalPhase.new(pending_orders: [ 2 ])

    cs = phase.handle(:remove_settlement, game: @game, player_order: @actor.order, row: 4, col: 4)

    assert_kind_of Turn::Consequences::Error, cs.first
  end

  test "remove_settlement emits tile forfeit for removed owner's unsupported location tile" do
    @opponent.update!(tiles: [ { "klass" => "PaddockTile", "from" => "[4, 5]", "used" => false } ])
    @game.board_contents.place_settlement(4, 4, @opponent.order)
    @game.board_contents.place_tile(4, 5, "PaddockTile", 2)
    phase = Turn::SubPhases::TargetedRemovalPhase.new(pending_orders: [ @opponent.order ])

    cs = phase.handle(:remove_settlement, game: @game, player_order: @actor.order, row: 4, col: 4)

    discard = cs.find { |c| c.is_a?(Turn::Consequences::TileDiscarded) && c.player == @opponent.order }
    refute_nil discard
    assert_equal "PaddockTile", discard.klass
  end
end
