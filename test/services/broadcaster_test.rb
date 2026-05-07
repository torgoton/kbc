require "test_helper"
require "turbo/broadcastable/test_helper"

class BroadcasterTest < ActiveSupport::TestCase
  include Turbo::Broadcastable::TestHelper

  def setup
    @game = Game.create!(state: "waiting")
    @game.add_player(users(:chris))
    @game.add_player(users(:paula))
    @game.start
    @game.reload
  end

  def player(order) = @game.game_players.find { |gp| gp.order == order }

  test "no consequences ⇒ no plans" do
    assert_empty Broadcaster.new(@game, []).plans
  end

  test "SettlementPlaced ⇒ board + turn-state plans" do
    plans = Broadcaster.new(@game, [
      Turn::Consequences::SettlementPlaced.new(at: Coordinate.new(5, 7), player: 0, terrain: "G")
    ]).plans
    targets = plans.map(&:target)
    assert_includes targets, "board"
    assert_includes targets, "turn-state"
  end

  test "SubPhasePushed alone ⇒ turn-state plan only" do
    plans = Broadcaster.new(@game, [
      Turn::Consequences::SubPhasePushed.new(phase_type: "tile_build", state: {})
    ]).plans
    targets = plans.map(&:target)
    assert_includes targets, "turn-state"
    refute_includes targets, "board"
  end

  test "TileConsumed for player 0 ⇒ that player's panel only" do
    plans = Broadcaster.new(@game, [
      Turn::Consequences::TileConsumed.new(klass: "FarmTile", player: 0)
    ]).plans
    panel_targets = plans.map(&:target).grep(/\Agame_player_/)
    assert_equal [ "game_player_#{player(0).id}" ], panel_targets
  end

  test "deduplicates within one publish — board appears at most once" do
    plans = Broadcaster.new(@game, [
      Turn::Consequences::SettlementPlaced.new(at: Coordinate.new(5, 7), player: 0, terrain: "G"),
      Turn::Consequences::TilePickedUp.new(from: Coordinate.new(3, 4), klass: "OracleTile", player: 0)
    ]).plans
    assert_equal 1, plans.count { |p| p.target == "board" }
    assert_equal 1, plans.count { |p| p.target == "turn-state" }
  end

  test "publish actually emits Turbo Streams to the planned channels" do
    consequences = [
      Turn::Consequences::SettlementPlaced.new(at: Coordinate.new(5, 7), player: 0, terrain: "G")
    ]
    assert_turbo_stream_broadcasts("game_#{@game.id}") do
      Broadcaster.publish(@game, consequences)
    end
  end
end
