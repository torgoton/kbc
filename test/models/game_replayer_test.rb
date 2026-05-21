require "test_helper"

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

    assert_equal [ "T" ], chris_snap["hand"]
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

  private

  def game_with_known_state
    game = games(:game2player)
    game.boards = [ [ 1, 0 ], [ 5, 0 ], [ 0, 0 ], [ 4, 0 ] ]
    game.board_contents = BoardState.new.tap { |s| s.place_tile(2, 7, "OasisTile", 1) }
    game.deck = [ "T", "G", "C", "D", "F" ]
    game.discard = []
    game.mandatory_count = 3
    game.current_action = { "type" => "mandatory" }
    game.save
    game_players(:chris).update!(hand: [ "T" ], supply: { "settlements" => 40 })
    game_players(:paula).update!(hand: [ "D" ], supply: { "settlements" => 40 })
    game.reload
    game
  end
end
