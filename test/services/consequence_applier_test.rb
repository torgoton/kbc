require "test_helper"

class ConsequenceApplierTest < ActiveSupport::TestCase
  def setup
    @game = Game.create!(state: "waiting")
    @game.add_player(users(:chris))
    @game.add_player(users(:paula))
    @game.start
    @game.reload
    @game.instantiate
  end

  def player(order) = @game.game_players.find { |gp| gp.order == order }

  test "applies a single SettlementPlaced and persists board + supply" do
    before = player(0).settlements_remaining
    ConsequenceApplier.apply!(@game, [
      Turn::Consequences::SettlementPlaced.new(at: Coordinate.new(5, 7), player: 0, terrain: "G")
    ])

    @game.reload
    assert_equal 0, @game.board_contents.player_at(5, 7)
    assert_equal before - 1, player(0).reload.settlements_remaining
  end

  test "applies consequences in order" do
    @game.board_contents.place_tile(3, 4, "OracleTile", 2)

    ConsequenceApplier.apply!(@game, [
      Turn::Consequences::SettlementPlaced.new(at: Coordinate.new(5, 7), player: 0, terrain: "G"),
      Turn::Consequences::TilePickedUp.new(from: Coordinate.new(3, 4), klass: "OracleTile", player: 0)
    ])

    @game.reload
    assert_equal 0, @game.board_contents.player_at(5, 7)
    assert_equal 1, @game.board_contents.tile_qty(3, 4)
    assert(player(0).reload.tiles.any? { |t| t["klass"] == "OracleTile" })
  end

  test "raises ApplyError if any consequence is an Error and rolls back" do
    before = player(0).settlements_remaining

    assert_raises(ConsequenceApplier::ApplyError) do
      ConsequenceApplier.apply!(@game, [
        Turn::Consequences::SettlementPlaced.new(at: Coordinate.new(5, 7), player: 0, terrain: "G"),
        Turn::Consequences::Error.new(message: "nope")
      ])
    end

    @game.reload
    assert @game.board_contents.empty?(5, 7)
    assert_equal before, player(0).reload.settlements_remaining
  end

  test "rolls back when an apply! raises mid-stream" do
    @game.board_contents.place_tile(3, 4, "OracleTile", 0)
    before = player(0).settlements_remaining

    assert_raises(StandardError) do
      ConsequenceApplier.apply!(@game, [
        Turn::Consequences::SettlementPlaced.new(at: Coordinate.new(5, 7), player: 0, terrain: "G"),
        Turn::Consequences::TilePickedUp.new(from: Coordinate.new(3, 4), klass: "OracleTile", player: 0)
      ])
    end

    @game.reload
    assert @game.board_contents.empty?(5, 7)
    assert_equal before, player(0).reload.settlements_remaining
  end

  test "persists SubPhasePushed and SubPhasePopped" do
    ConsequenceApplier.apply!(@game, [
      Turn::Consequences::SubPhasePushed.new(
        phase_type: Turn::SubPhases::TileBuildPhase::TYPE,
        state: { "restricted_terrain" => "G", "tile_klass" => "FarmTile", "tile_source" => "[3, 4]" }
      )
    ])
    @game.reload
    assert_equal "tile_build", @game.current_action.dig("turn", "sub_phase", "type")

    ConsequenceApplier.apply!(@game, [ Turn::Consequences::SubPhasePopped.new(prior_state: { "type" => "tile_build", "state" => {} }) ])
    @game.reload
    assert_nil @game.current_action.dig("turn", "sub_phase")
  end

  test "unapply! reverses a single SettlementPlaced and persists" do
    before = player(0).settlements_remaining
    ConsequenceApplier.apply!(@game, [
      Turn::Consequences::SettlementPlaced.new(at: Coordinate.new(5, 7), player: 0, terrain: "G")
    ])
    ConsequenceApplier.unapply!(@game.reload)

    @game.reload
    @game.instantiate
    assert_nil @game.board_contents.player_at(5, 7)
    assert_equal before, player(0).reload.settlements_remaining
  end

  test "unapply! reverses consequences in reverse order" do
    @game.board_contents.place_tile(3, 4, "OracleTile", 2)
    @game.save!

    ConsequenceApplier.apply!(@game, [
      Turn::Consequences::SettlementPlaced.new(at: Coordinate.new(5, 7), player: 0, terrain: "G"),
      Turn::Consequences::TilePickedUp.new(from: Coordinate.new(3, 4), klass: "OracleTile", player: 0)
    ])
    ConsequenceApplier.unapply!(@game.reload)

    @game.reload
    @game.instantiate
    assert_nil @game.board_contents.player_at(5, 7)
    assert_equal 2, @game.board_contents.tile_qty(3, 4)
    refute(player(0).reload.tiles.any? { |t| t["klass"] == "OracleTile" })
  end

  test "unapply! is a no-op when there is no recorded click" do
    assert_nothing_raised { ConsequenceApplier.unapply!(@game) }
  end

  test "apply! creates a TurnClick with the serialized consequences" do
    assert_difference -> { TurnClick.count }, 1 do
      ConsequenceApplier.apply!(@game, [
        Turn::Consequences::SettlementPlaced.new(at: Coordinate.new(5, 7), player: 0, terrain: "G")
      ])
    end
    click = TurnClick.most_recent_for(@game)
    assert_equal 1, click.consequences.size
    assert_equal "settlement_placed", click.consequences.first["type"]
  end

  test "apply! gives each click a monotonic order per game" do
    ConsequenceApplier.apply!(@game, [ Turn::Consequences::SettlementPlaced.new(at: Coordinate.new(5, 7), player: 0, terrain: "G") ])
    ConsequenceApplier.apply!(@game, [ Turn::Consequences::SettlementPlaced.new(at: Coordinate.new(5, 8), player: 0, terrain: "G") ])
    orders = TurnClick.where(game: @game).pluck(:order).sort
    assert_equal [ 1, 2 ], orders
  end

  test "apply! does not create a TurnClick when an Error is in the list" do
    assert_no_difference -> { TurnClick.count } do
      assert_raises(ConsequenceApplier::ApplyError) do
        ConsequenceApplier.apply!(@game, [ Turn::Consequences::Error.new(message: "x") ])
      end
    end
  end

  test "unapply! deletes the click record it consumed" do
    ConsequenceApplier.apply!(@game, [
      Turn::Consequences::SettlementPlaced.new(at: Coordinate.new(5, 7), player: 0, terrain: "G")
    ])
    assert_difference -> { TurnClick.count }, -1 do
      ConsequenceApplier.unapply!(@game.reload)
    end
  end

  test "unapply! only consumes one click at a time" do
    ConsequenceApplier.apply!(@game, [ Turn::Consequences::SettlementPlaced.new(at: Coordinate.new(5, 7), player: 0, terrain: "G") ])
    ConsequenceApplier.apply!(@game, [ Turn::Consequences::SettlementPlaced.new(at: Coordinate.new(5, 8), player: 0, terrain: "G") ])
    ConsequenceApplier.unapply!(@game.reload)

    @game.reload
    @game.instantiate
    assert_nil @game.board_contents.player_at(5, 8)
    assert_equal 0, @game.board_contents.player_at(5, 7)
    assert_equal 1, TurnClick.where(game: @game).count
  end
end
