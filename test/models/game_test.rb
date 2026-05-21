# == Schema Information
#
# Table name: games
#
#  id                :bigint           not null, primary key
#  base_snapshot     :jsonb
#  board_contents    :json
#  boards            :json
#  current_action    :json
#  deck              :json
#  discard           :json
#  end_trigger_count :integer          default(0), not null
#  goals             :json
#  mandatory_count   :integer
#  move_count        :integer
#  scores            :json
#  state             :string
#  stone_walls       :integer          default(25), not null
#  tasks             :json
#  turn_number       :integer          default(0), not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  current_player_id :integer
#
# Indexes
#
#  index_games_on_current_player_id  (current_player_id)
#
require "test_helper"

require "turbo/broadcastable/test_helper"

class GameTest < ActiveSupport::TestCase
  include Turbo::Broadcastable::TestHelper

  test "populate_player_supplies initializes tiles with MandatoryTile hash" do
    game = games(:game2player)
    game.send(:populate_player_supplies)

    chris = game_players(:chris).reload
    assert_equal [ { "klass" => "MandatoryTile", "used" => true } ], chris.tiles
  end

  # ── End-game modal ───────────────────────────────────────────────────────────

  test "winners returns the player(s) with the highest total score" do
    game = games(:game2player)
    chris = game_players(:chris)
    paula = game_players(:paula)
    game.scores = {
      chris.order.to_s => { "total" => 10 },
      paula.order.to_s => { "total" => 6 }
    }
    game.save

    assert_equal [ chris ], game.winners
  end

  test "winners returns all tied players when scores are equal" do
    game = games(:game2player)
    chris = game_players(:chris)
    paula = game_players(:paula)
    game.scores = {
      chris.order.to_s => { "total" => 8 },
      paula.order.to_s => { "total" => 8 }
    }
    game.save

    assert_equal [ chris, paula ].map(&:id).sort, game.winners.map(&:id).sort
  end

  test "winners returns empty when scores are not yet stored" do
    game = games(:game2player)
    assert_empty game.winners
  end

  # ── Live scores ──────────────────────────────────────────────────────────────

  test "live_scores returns a hash keyed by player order with goal breakdowns and total" do
    game = games(:game2player)
    game.boards = [ [ 1, 0 ], [ 5, 0 ], [ 0, 0 ], [ 4, 0 ] ]
    game.goals  = [ "castles", "fishermen", "knights", "merchants" ]
    game.save

    result = game.live_scores

    assert result.key?(game_players(:chris).order.to_s)
    assert result.key?(game_players(:paula).order.to_s)
    chris_scores = result[game_players(:chris).order.to_s]
    assert chris_scores.key?("castles")
    assert chris_scores.key?("total")
  end

  # ── complete! ────────────────────────────────────────────────────────────────

  test "complete! sets state to completed and populates scores" do
    game = new_started_game
    game.complete!
    game.reload

    assert_equal "completed", game.state
    assert_not_nil game.scores, "scores must be stored"
    assert game.scores.key?(game.game_players.first.order.to_s), "scores keyed by player order"
  end

  # ── turn_state ───────────────────────────────────────────────────────────────

  test "turn_state returns 'Waiting for players' for waiting games" do
    assert_equal "Waiting for players", games(:chris_waiting_game).turn_state
  end

  test "turn_state returns a mandatory build message for playing games" do
    game = games(:game2player)
    game.update!(current_action: { "turn" => { "mandatory_remaining" => 3 } })
    game.current_player.update!(hand: [ "G" ])

    assert_match(/must build/, game.turn_state)
  end

  # ── Broadcasts ───────────────────────────────────────────────────────────────

  test "broadcast_dashboard_update sends to each participant's user channel" do
    game = games(:game2player)
    chris = users(:chris)
    paula = users(:paula)

    assert_turbo_stream_broadcasts("user_#{chris.id}") do
      assert_turbo_stream_broadcasts("user_#{paula.id}") do
        game.broadcast_dashboard_update
      end
    end
  end

  test "complete! broadcasts dashboard update to participants" do
    game = games(:game2player)
    chris = users(:chris)

    assert_turbo_stream_broadcasts("user_#{chris.id}") do
      game.complete!
    end
  end

  # ── Board selection ──────────────────────────────────────────────────────────

  test "start selects 4 unique boards from the known pool" do
    game = new_started_game
    board_ids = game.boards.map(&:first)
    assert_equal 4, board_ids.size
    assert_equal board_ids.uniq, board_ids
    assert board_ids.all? { |id| (0...Boards::BoardSection::SECTIONS.size).include?(id) }
  end

  test "start randomizes board selection across games" do
    boards_seen = 10.times.map { new_started_game.boards.map(&:first) }
    assert boards_seen.uniq.size > 1, "expected varied board selection, got always #{boards_seen.first}"
  end

  # ── broadcast_game_update ────────────────────────────────────────────────────

  test "broadcast_game_update broadcasts dashboard update to participants" do
    game = games(:game2player)
    chris = users(:chris)

    assert_turbo_stream_broadcasts("user_#{chris.id}") do
      game.broadcast_game_update
    end
  end

  test "broadcast_game_update does not publish personalized player panels to the public game stream" do
    game = games(:game2player)
    chris = game_players(:chris)
    TurnClick.create!(game: game,
      order: 1,
      consequences: [],
      reversible: true
    )

    broadcasts = capture_turbo_stream_broadcasts("game_#{game.id}") do
      game.broadcast_game_update
    end

    assert broadcasts.none? { |broadcast| broadcast.to_s.include?(%(target="game_player_#{chris.id}")) },
      "public game stream must not overwrite Chris's private player panel"
  end

  test "broadcast_game_update sends each user a private personalized player area" do
    game = games(:game2player)
    chris = game_players(:chris)
    paula = game_players(:paula)
    game.update!(
      boards: [ [ 1, 0 ], [ 5, 0 ], [ 0, 0 ], [ 4, 0 ] ],
      board_contents: BoardState.new,
      current_action: { "turn" => { "mandatory_remaining" => 0 } }
    )
    chris.update!(
      hand: [ "T" ],
      tiles: [
        { "klass" => "OasisTile", "from" => "[2, 7]", "used" => false }
      ]
    )
    TurnClick.create!(game: game,
      order: 1,
      consequences: [],
      reversible: true
    )

    broadcasts = capture_turbo_stream_broadcasts("game_player_#{chris.id}_private") do
      game.broadcast_game_update
    end

    chris_panel = broadcasts.find { |broadcast| broadcast.to_s.include?(%(target="game_player_#{chris.id}")) }
    paula_panel = broadcasts.find { |broadcast| broadcast.to_s.include?(%(target="game_player_#{paula.id}")) }

    assert chris_panel, "expected Chris's private stream to update his own panel"
    assert paula_panel, "expected Chris's private stream to update Paula's opponent panel"
    assert_includes chris_panel.to_s, "Undo"
    assert_not_includes paula_panel.to_s, "Undo"
    assert_includes chris_panel.to_s, %(action="/games/#{game.id}/select_action")
    assert_includes chris_panel.to_s, "tile-activatable"
    assert_includes chris_panel.to_s, "card-T"
    assert_not_includes chris_panel.to_s, "card-Z"
  end

  test "broadcast_sound emits a play_sound turbo stream to the game channel" do
    game = games(:game2player)
    broadcasts = capture_turbo_stream_broadcasts("game_#{game.id}") do
      game.broadcast_sound("undo")
    end
    assert broadcasts.any? { |b| b.to_s.include?(%(action="play_sound")) && b.to_s.include?(%(key="undo")) },
      "expected a play_sound[key=undo] broadcast, got: #{broadcasts.inspect}"
  end

  test "broadcast_sound refuses keys containing HTML-hostile characters" do
    game = games(:game2player)
    [ %(a"b), "a<b", "a>b", "a/b", "a b", "a\nb", "a.b", "a1b", "" ].each do |hostile|
      assert_no_turbo_stream_broadcasts("game_#{game.id}") do
        game.broadcast_sound(hostile)
      end
    end
  end

  private

  def new_started_game
    game = Game.create!(state: "waiting")
    game.add_player(users(:chris))
    game.add_player(users(:paula))
    game.start
    game.reload
    game
  end
end
