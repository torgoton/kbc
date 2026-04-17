require "test_helper"

# Tests for the event-sourcing replay mechanism.
#
# Core invariant: after any sequence of moves, replaying all moves from the
# base_snapshot must produce the same state as game.capture_snapshot (the
# current materialized snapshot). If these diverge, an event payload is wrong
# or the replayer has a bug.
#
# Setup for most tests:
#   Oasis board at index 0 (rows 0-9, cols 0-9).
#   Tile location at (2,7). Row 1 col 7 is adjacent "T" terrain.
#   Chris (order 0) has hand "T"; Paula (order 1) has hand "D".
#   Known deck: ["T","G","C","D","F"] so draws are deterministic.

class GameReplayerTest < ActiveSupport::TestCase
  # ---------------------------------------------------------------------------
  # capture_snapshot
  # ---------------------------------------------------------------------------

  test "capture_snapshot includes all fields needed for replay" do
    game = game_with_known_state

    snap = game.capture_snapshot

    assert_equal 3, snap["mandatory_count"]
    assert_equal [], snap["discard"]
    assert_equal [ "T", "G", "C", "D", "F" ], snap["deck"]
    assert_equal({ "type" => "mandatory" }, snap["current_action"])
    assert_equal 2, snap["players"].size
    assert_not_empty snap["board_contents"]  # tile at (2,7)
  end

  test "capture_snapshot records current_player_order" do
    game = game_with_known_state

    snap = game.capture_snapshot

    assert_equal game_players(:chris).order, snap["current_player_order"]
  end

  test "capture_snapshot records each player hand and supply" do
    game = game_with_known_state

    snap = game.capture_snapshot
    chris_snap = snap["players"].find { |p| p["order"] == game_players(:chris).order }

    assert_equal "T", chris_snap["hand"]
    assert_equal 40, chris_snap["supply"]["settlements"]
  end

  # ---------------------------------------------------------------------------
  # Game#start stores base_snapshot
  # ---------------------------------------------------------------------------

  test "start stores a base_snapshot after setup" do
    game = games(:game2player)
    game.start(false)
    game.reload

    assert_not_nil game.base_snapshot
    assert_equal 3, game.base_snapshot["mandatory_count"]
    assert_equal 2, game.base_snapshot["players"].size
    assert_not_empty game.base_snapshot["board_contents"]
    assert_not_empty game.base_snapshot["deck"]
  end

  # ---------------------------------------------------------------------------
  # replayed_state: each action type
  # ---------------------------------------------------------------------------

  test "replayed_state matches current state after build (with tile pickup)" do
    game = game_with_known_state
    engine(game).build_settlement(1, 7)   # Chris plays "T" at (1,7), picks up OasisTile
    game.reload

    assert_states_equal game.capture_snapshot, game.replayed_state
  end

  test "capture_snapshot and replayed_state both include taken_from after a pickup" do
    game = game_with_known_state
    engine(game).build_settlement(1, 7)
    game.reload
    order = game_players(:chris).order

    snap_player = game.capture_snapshot["players"].find { |p| p["order"] == order }
    replay_player = game.replayed_state["players"].find { |p| p["order"] == order }

    assert_equal [ "[2, 7]" ], snap_player["taken_from"]
    assert_equal [ "[2, 7]" ], replay_player["taken_from"]
  end

  test "replayed_state matches current state after build without tile pickup" do
    game = game_with_known_state
    # Build at (0,0) — far from the tile location at (2,7)
    engine(game).build_settlement(0, 0)
    game.reload

    assert_states_equal game.capture_snapshot, game.replayed_state
  end

  test "replayed_state matches current state after end_turn (no reshuffle)" do
    game = game_with_known_state
    game.mandatory_count = 0
    game.save

    engine(game).end_turn   # Chris discards "T", draws "T" (first card in deck)
    game.reload

    assert_states_equal game.capture_snapshot, game.replayed_state
  end

  test "replayed_state matches current state after end_turn with reshuffle" do
    game = game_with_known_state
    game.deck = [ "C" ]             # only one card left
    game.discard = [ "D", "F" ]
    game.mandatory_count = 0
    game.save

    engine(game).end_turn
    game.reload

    assert_states_equal game.capture_snapshot, game.replayed_state
  end

  test "replayed_state matches current state after select_action" do
    game = games(:game2player)
    chris = game_players(:chris)
    game.boards = [ [ "Oasis", 0 ], [ "Paddock", 0 ], [ "Farm", 0 ], [ "Tavern", 0 ] ]
    game.save
    chris.tiles = [ { "klass" => "PaddockTile", "from" => "[2, 18]", "used" => false } ]
    chris.save
    game.reload
    game.update(base_snapshot: game.capture_snapshot)

    engine(game).select_action("paddock")
    game.reload

    assert_states_equal game.capture_snapshot, game.replayed_state
  end

  test "replayed_state matches current state after select_settlement" do
    game = game_with_known_state
    chris = game_players(:chris)
    game.board_contents = BoardState.new.tap do |s|
      s.place_settlement(5, 5, chris.order)
    end
    game.current_action = { "type" => "paddock" }
    game.save
    game.update(base_snapshot: game.capture_snapshot)

    engine(game).select_settlement(5, 5)
    game.reload

    assert_states_equal game.capture_snapshot, game.replayed_state
  end

  test "replayed_state matches current state after move_settlement" do
    game = game_with_known_state
    chris = game_players(:chris)
    game.board_contents = BoardState.new.tap { |s| s.place_settlement(5, 5, chris.order) }
    game.current_action = { "type" => "paddock", "from" => "[5, 5]" }
    game.save
    game.update(base_snapshot: game.capture_snapshot)

    engine(game).move_settlement(5, 7)
    game.reload

    assert_states_equal game.capture_snapshot, game.replayed_state
  end

  test "replayed_state matches current state after build_on_terrain (oasis action)" do
    game = game_with_known_state
    chris = game_players(:chris)
    game.board_contents = BoardState.new.tap { |s| s.place_settlement(0, 2, chris.order) }
    game.current_action = { "type" => "oasis" }
    game.save
    chris.tiles = [ { "klass" => "OasisTile", "from" => "[2, 7]", "used" => false } ]
    chris.save
    game.reload   # clear association cache so capture_snapshot and current_player see fresh data
    game.update(base_snapshot: game.capture_snapshot)

    engine(game).activate_tile_build(0, 1)
    game.reload

    assert_states_equal game.capture_snapshot, game.replayed_state
  end

  test "replayed_state matches current state after forfeit_tile" do
    game = game_with_known_state
    chris = game_players(:chris)
    game.board_contents = BoardState.new.tap do |s|
      s.place_tile(2, 7, "OasisTile", 0)
      s.place_settlement(1, 7, chris.order)
    end
    game.current_action = { "type" => "paddock", "from" => "[1, 7]" }
    game.save
    chris.tiles = [ { "klass" => "OasisTile", "from" => "[2, 7]", "used" => false } ]
    chris.save
    game.reload   # clear association cache
    game.update(base_snapshot: game.capture_snapshot)

    engine(game).move_settlement(1, 5)   # triggers forfeit_tile
    game.reload

    assert_states_equal game.capture_snapshot, game.replayed_state
  end

  test "replayed_state matches current state after a multi-step sequence" do
    game = game_with_known_state
    # Build three times (mandatory_count = 3), then end the turn
    engine(game).build_settlement(0, 0)
    engine(game).build_settlement(0, 2)
    engine(game).build_settlement(0, 4)
    game.mandatory_count = 0
    game.save
    engine(game).end_turn
    game.reload

    assert_states_equal game.capture_snapshot, game.replayed_state
  end

  private

  def engine(game)
    TurnEngine.new(game)
  end

  # Returns a saved game with a known, deterministic initial state and a
  # base_snapshot already captured.
  def game_with_known_state
    game = games(:game2player)
    game.boards = [ [ "Oasis", 0 ], [ "Paddock", 0 ], [ "Farm", 0 ], [ "Tavern", 0 ] ]
    game.board_contents = BoardState.new.tap { |s| s.place_tile(2, 7, "OasisTile", 2) }
    game.deck = [ "T", "G", "C", "D", "F" ]
    game.discard = []
    game.goals = [ "Fishermen", "Knights", "Merchants" ]
    game.mandatory_count = 3
    game.current_action = { "type" => "mandatory" }
    game.save
    # Chris: hand "T", Paula: hand "D" (from fixtures)
    game.update(base_snapshot: game.capture_snapshot)
    game
  end

  # Normalizes non-deterministic ordering before comparing two state hashes.
  def normalize_state(state)
    state.merge(
      "board_contents" => state["board_contents"].sort_by { |e| [ e["r"], e["c"] ] },
      "players" => state["players"].sort_by { |p| p["order"] }
    )
  end

  def assert_states_equal(expected, actual)
    assert_equal normalize_state(expected), normalize_state(actual)
  end
end
