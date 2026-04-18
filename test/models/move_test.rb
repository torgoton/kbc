require "test_helper"

class MoveTest < ActiveSupport::TestCase
  def build_move(action:, payload: nil)
    game = games(:game2player)
    gp = game_players(:chris)
    Move.new(game: game, game_player: gp, action: action, payload: payload, order: 1)
  end

  test "sound_key maps mapped actions to their keys" do
    expected = {
      "build" => "build",
      "select_settlement" => "select_settlement",
      "move_settlement" => "move",
      "pick_up_tile" => "tile_pickup",
      "forfeit_tile" => "tile_forfeit",
      "end_turn" => "end_turn",
      "end_game" => "game_end",
      "remove_settlement" => "removed",
      "activate_outpost" => "outpost",
      "place_wall" => "wall"
    }
    expected.each do |action, key|
      assert_equal key, build_move(action: action).send(:sound_key), "#{action} should map to #{key}"
    end
  end

  test "sound_key derives select_action sound from payload klass" do
    move = build_move(action: "select_action", payload: { "klass" => "PaddockTile" })
    assert_equal "paddock", move.send(:sound_key)

    move = build_move(action: "select_action", payload: { "klass" => "OasisTile" })
    assert_equal "oasis", move.send(:sound_key)
  end

  test "sound_key returns nil for unmapped actions" do
    assert_nil build_move(action: "score_goal").send(:sound_key)
    assert_nil build_move(action: "select_action").send(:sound_key)
    assert_nil build_move(action: "select_action", payload: {}).send(:sound_key)
  end
end
