require "test_helper"
require "turbo/broadcastable/test_helper"

# Slice 1 integration test: Farm tile activation + Grass build, end-to-end
# through the new stack (Turn → sub-phase → consequences → ConsequenceApplier
# → Broadcaster). No controller, no comparison with the old engine; that's
# slice 1.5.
class FarmSliceThroughNewStackTest < ActiveSupport::TestCase
  include Turbo::Broadcastable::TestHelper

  def setup
    @game = Game.create!(state: "waiting")
    @game.add_player(users(:chris))
    @game.add_player(users(:paula))
    @game.start
    @game.reload
    @game.instantiate

    @player = @game.current_player
    @farm_source = "[3, 4]"
    @player.update!(tiles: [ { "klass" => "FarmTile", "from" => @farm_source, "used" => false } ])
    @game.reload
  end

  test "Farm activation followed by Grass build: applies and persists end-to-end" do
    settlements_before = @player.settlements_remaining

    # 1. Activate Farm.
    activation = Turn.from_game(@game).handle(:select_action, game: @game, tile: :farm)
    ConsequenceApplier.apply!(@game, activation)
    Broadcaster.publish(@game, activation)

    @game.reload
    sub_phase_state = @game.current_action.dig("turn", "sub_phase")
    assert_equal "tile_build", sub_phase_state["type"]
    assert_equal "G", sub_phase_state.dig("state", "restricted_terrain")
    assert_equal "FarmTile", sub_phase_state.dig("state", "tile_klass")
    assert_equal @farm_source, sub_phase_state.dig("state", "tile_source")

    # 2. Build on a Grass hex.
    @game.instantiate
    row, col = first_empty_grass

    build = Turn.from_game(@game).handle(:build, game: @game, row:, col:)
    ConsequenceApplier.apply!(@game, build)
    Broadcaster.publish(@game, build)

    @game.reload
    assert_equal @player.order, @game.board_contents.player_at(row, col)
    assert_equal settlements_before - 1, @player.reload.settlements_remaining

    farm_tile = @player.tiles.find { |t| t["klass"] == "FarmTile" }
    assert_equal true, farm_tile["used"], "Farm tile should be marked used after build"

    assert_nil @game.current_action.dig("turn", "sub_phase"), "sub_phase should be popped after build"
  end

  test "build emits a board broadcast" do
    activation = Turn.from_game(@game).handle(:select_action, game: @game, tile: :farm)
    ConsequenceApplier.apply!(@game, activation)
    @game.reload
    @game.instantiate
    row, col = first_empty_grass

    build = Turn.from_game(@game).handle(:build, game: @game, row:, col:)
    ConsequenceApplier.apply!(@game, build)

    assert_turbo_stream_broadcasts("game_#{@game.id}") do
      Broadcaster.publish(@game, build)
    end
  end

  test "activation when player has no Farm tile is rejected (no state changes)" do
    @player.update!(tiles: [])
    @game.reload
    settlements_before = @player.settlements_remaining

    consequences = Turn.from_game(@game).handle(:select_action, game: @game, tile: :farm)
    assert_kind_of Turn::Consequences::Error, consequences.first
    assert_raises(ConsequenceApplier::ApplyError) do
      ConsequenceApplier.apply!(@game, consequences)
    end

    @game.reload
    assert_equal settlements_before, @player.reload.settlements_remaining
    assert_nil @game.current_action.dig("turn", "sub_phase") if @game.current_action
  end

  test "build on a non-Grass hex during Farm sub-phase is rejected and sub-phase remains active" do
    activation = Turn.from_game(@game).handle(:select_action, game: @game, tile: :farm)
    ConsequenceApplier.apply!(@game, activation)
    @game.reload
    @game.instantiate

    non_grass = first_empty_non_grass
    consequences = Turn.from_game(@game).handle(:build, game: @game, row: non_grass[0], col: non_grass[1])
    assert_kind_of Turn::Consequences::Error, consequences.first

    assert_raises(ConsequenceApplier::ApplyError) do
      ConsequenceApplier.apply!(@game, consequences)
    end

    @game.reload
    assert_not_nil @game.current_action.dig("turn", "sub_phase")
  end

  private

  def first_empty_grass
    20.times do |row|
      20.times do |col|
        next unless @game.board.terrain_at(row, col) == "G"
        return [ row, col ] if @game.board_contents.empty?(row, col)
      end
    end
    raise "no empty grass hex"
  end

  def first_empty_non_grass
    20.times do |row|
      20.times do |col|
        terrain = @game.board.terrain_at(row, col)
        next if terrain.nil? || terrain == "G" || terrain == "L" || terrain == "S"
        return [ row, col ] if @game.board_contents.empty?(row, col)
      end
    end
    raise "no empty non-grass hex"
  end
end
