# == Schema Information
#
# Table name: moves
#
#  id             :bigint           not null, primary key
#  action         :string
#  deliberate     :boolean
#  from           :string
#  message        :string
#  order          :integer
#  payload        :jsonb
#  reversible     :boolean
#  to             :string
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  game_id        :bigint           not null
#  game_player_id :bigint           not null
#
# Indexes
#
#  index_moves_on_game_id         (game_id)
#  index_moves_on_game_player_id  (game_player_id)
#
# Foreign Keys
#
#  fk_rails_...  (game_id => games.id)
#  fk_rails_...  (game_player_id => game_players.id)
#
require "test_helper"
require "turbo/broadcastable/test_helper"

class MoveTest < ActiveSupport::TestCase
  include Turbo::Broadcastable::TestHelper
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

  test "creating a Move broadcasts a play_sound turbo stream with the mapped key" do
    game = games(:game2player)
    gp = game_players(:chris)
    assert_turbo_stream_broadcasts("game_#{game.id}") do
      game.moves.create!(game_player: gp, action: "build", order: 1)
    end
  end

  test "creating a Move with unmapped action does not broadcast" do
    game = games(:game2player)
    gp = game_players(:chris)
    assert_no_turbo_stream_broadcasts("game_#{game.id}") do
      game.moves.create!(game_player: gp, action: "score_goal", order: 2)
    end
  end

  test "creating a Move with a malicious select_action payload does not broadcast" do
    game = games(:game2player)
    gp = game_players(:chris)
    assert_no_turbo_stream_broadcasts("game_#{game.id}") do
      game.moves.create!(
        game_player: gp,
        action: "select_action",
        payload: { "klass" => "Foo\"><script>alert(1)</script><xTile" },
        order: 3
      )
    end
  end
end
