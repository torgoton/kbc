require "test_helper"

class TimedGameSweepJobTest < ActiveSupport::TestCase
  test "auto-resigns the current player once their live bank is well past -10 minutes" do
    game = new_started_game(speed: "blitz")
    current = game.current_player
    current.update!(clock_started_at: Time.current, time_remaining_ms: 0)

    travel 11.minutes do
      TimedGameSweepJob.perform_now
    end

    assert current.reload.resigned?
    assert_equal "completed", game.reload.state
  end

  test "leaves a player flagged by less than 10 minutes alone" do
    game = new_started_game(speed: "blitz")
    current = game.current_player
    current.update!(clock_started_at: Time.current, time_remaining_ms: 0)

    travel 5.minutes do
      TimedGameSweepJob.perform_now
    end

    assert_not current.reload.resigned?
    assert_equal "playing", game.reload.state
  end

  test "deletes a waiting timed table whose opener has been offline for 10 minutes" do
    game = Game.create!(state: "waiting", speed: "blitz")
    game.add_player(users(:chris))
    users(:chris).update!(last_seen_at: 11.minutes.ago)

    assert_difference("Game.count", -1) do
      TimedGameSweepJob.perform_now
    end
    assert_not Game.exists?(game.id)
  end

  test "does not delete a waiting untimed table whose opener is offline" do
    game = Game.create!(state: "waiting", speed: nil)
    game.add_player(users(:chris))
    users(:chris).update!(last_seen_at: 11.minutes.ago)

    assert_no_difference("Game.count") do
      TimedGameSweepJob.perform_now
    end
    assert Game.exists?(game.id)
  end

  test "does not delete a waiting timed table whose opener is still online" do
    game = Game.create!(state: "waiting", speed: "blitz")
    game.add_player(users(:chris))
    users(:chris).update!(last_seen_at: Time.current)

    assert_no_difference("Game.count") do
      TimedGameSweepJob.perform_now
    end
  end

  test "cancels a playing timed game whose current player never started their clock and is offline" do
    game = new_started_game(speed: "blitz")
    current = game.current_player
    current.update!(clock_started_at: nil)
    current.player.update!(last_seen_at: 11.minutes.ago)

    assert_difference("Game.count", -1) do
      TimedGameSweepJob.perform_now
    end
  end

  test "does not cancel a playing timed game whose current player has already made a move" do
    game = new_started_game(speed: "blitz")
    current = game.current_player
    current.update!(clock_started_at: Time.current)
    current.player.update!(last_seen_at: 11.minutes.ago)

    assert_no_difference("Game.count") do
      TimedGameSweepJob.perform_now
    end
  end

  test "does not cancel a playing timed game whose current player is online" do
    game = new_started_game(speed: "blitz")
    current = game.current_player
    current.update!(clock_started_at: nil)
    current.player.update!(last_seen_at: Time.current)

    assert_no_difference("Game.count") do
      TimedGameSweepJob.perform_now
    end
  end

  private

  def new_started_game(speed:)
    game = Game.create!(state: "waiting", speed: speed)
    game.add_player(users(:chris))
    game.add_player(users(:paula))
    game.start
    game.reload
  end
end
