require "test_helper"

# Slice 1 forward-compat probe: capture the consequence stream from running a
# Farm slice, reset the game to its pre-slice state, replay the stream, and
# assert the end state matches. Validates that the slice 1 consequence
# vocabulary is sufficient to reconstruct game state from events alone — the
# precondition for any future event-sourcing work.
class ReplayConsequenceStreamTest < ActiveSupport::TestCase
  def setup
    @game = Game.create!(state: "waiting")
    @game.add_player(users(:chris))
    @game.add_player(users(:paula))
    @game.start
    @game.reload
    @game.instantiate

    @player = @game.current_player
    @player.update!(tiles: [ { "klass" => "FarmTile", "from" => "[3, 4]", "used" => false } ])
    @game.reload
    @game.instantiate
  end

  test "consequence stream replays cleanly: end state matches first run" do
    snapshot = @game.capture_snapshot

    stream = []
    activation = Turn.from_game(@game).handle(:select_action, game: @game, tile: :farm)
    ConsequenceApplier.apply!(@game, activation)
    stream.concat(activation)

    @game.reload
    @game.instantiate
    row, col = first_empty_grass

    build = Turn.from_game(@game).handle(:build, game: @game, row:, col:)
    ConsequenceApplier.apply!(@game, build)
    stream.concat(build)

    @game.reload
    expected = end_state_fingerprint(@game)

    restore_from_snapshot(@game, snapshot)
    @game.reload

    ConsequenceApplier.apply!(@game, stream)
    @game.reload
    actual = end_state_fingerprint(@game)

    assert_equal expected, actual,
      "replay did not reproduce the same end state — consequence vocabulary is incomplete"
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

  def end_state_fingerprint(game)
    {
      "board_contents" => BoardState.dump(game.board_contents),
      "current_action" => game.current_action,
      "players" => game.game_players.in_player_order.map do |gp|
        gp.reload
        { "order" => gp.order, "supply" => gp.supply, "tiles" => gp.tiles, "taken_from" => gp.taken_from || [] }
      end
    }
  end

  def restore_from_snapshot(game, snap)
    game.board_contents = BoardState.load(snap["board_contents"])
    game.current_action = snap["current_action"]
    game.save!
    game.game_players.each do |gp|
      ps = snap["players"].find { |p| p["order"] == gp.order }
      gp.update!(hand: ps["hand"], supply: ps["supply"], tiles: ps["tiles"], taken_from: ps["taken_from"])
    end
  end
end
