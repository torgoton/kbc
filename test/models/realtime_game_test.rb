require "test_helper"

class RealtimeGameTest < ActiveSupport::TestCase
  def table(opener, realtime: true, invited: nil)
    Game.create!(state: "waiting", realtime: realtime, invited_user: invited).tap { |g| g.add_player(opener) }
  end

  def on_dashboard(user)
    Presence.create!(user: user, kind: "dashboard", connection_id: "d-#{user.id}", last_ping_at: Time.current)
  end

  def start_realtime_game(a, b)
    Game.create!(state: "playing", realtime: true).tap { |g| g.add_player(a); g.add_player(b) }
  end

  test "real-time table is listed only while its opener is on the dashboard" do
    game = table(users(:paula))
    assert_not_includes users(:chris).realtime_waiting_games, game

    on_dashboard(users(:paula))
    assert_includes users(:chris).realtime_waiting_games, game
  end

  test "real-time tables stay out of the regular waiting list, and vice versa" do
    rt = table(users(:paula))
    plain = table(users(:paula), realtime: false)
    on_dashboard(users(:paula))

    assert_not_includes users(:chris).waiting_games, rt
    assert_includes users(:chris).waiting_games, plain
    assert_not_includes users(:chris).realtime_waiting_games, plain
  end

  test "my own table is not offered to me" do
    on_dashboard(users(:paula))
    game = table(users(:paula))
    assert_not_includes users(:paula).realtime_waiting_games, game
  end

  test "an opener in a playing real-time game has other tables hidden" do
    on_dashboard(users(:paula))
    game = table(users(:paula))
    start_realtime_game(users(:paula), users(:jules))

    assert_not_includes users(:chris).realtime_waiting_games, game
    assert_not game.joinable_by?(users(:chris))
  end

  test "tables reappear when the busy game ends" do
    on_dashboard(users(:paula))
    game = table(users(:paula))
    busy = start_realtime_game(users(:paula), users(:jules))
    busy.update!(state: "completed")

    assert_includes users(:chris).realtime_waiting_games, game
  end

  test "someone in a playing real-time game cannot join another real-time table" do
    on_dashboard(users(:paula))
    game = table(users(:paula))
    start_realtime_game(users(:chris), users(:jules))

    assert_not game.joinable_by?(users(:chris))
  end

  test "an invited table is visible and joinable only by the invitee" do
    game = table(users(:paula), realtime: false, invited: users(:jules))

    assert_includes users(:jules).waiting_games, game
    assert_not_includes users(:chris).waiting_games, game
    assert game.joinable_by?(users(:jules))
    assert_not game.joinable_by?(users(:chris))
  end

  test "invited real-time table still needs the opener on the dashboard" do
    game = table(users(:paula), invited: users(:jules))
    assert_not_includes users(:jules).realtime_waiting_games, game
    on_dashboard(users(:paula))
    assert_includes users(:jules).realtime_waiting_games, game
    assert_not_includes users(:chris).realtime_waiting_games, game
  end

  test "opener is the first player seated" do
    assert_equal users(:paula), table(users(:paula)).opener
  end

  test "my_games lists real-time games first" do
    rt = table(users(:chris))
    games = users(:chris).my_games.to_a

    assert_equal rt, games.first
    assert_operator games.size, :>, 1
  end
end
