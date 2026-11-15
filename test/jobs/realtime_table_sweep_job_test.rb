require "test_helper"

class RealtimeTableSweepJobTest < ActiveJob::TestCase
  def table(opener)
    Game.create!(state: "waiting", realtime: true).tap { |g| g.add_player(opener) }
  end

  test "deletes a table whose opener left the dashboard 10+ minutes ago" do
    game = table(users(:paula))
    users(:paula).update!(dashboard_seen_at: 11.minutes.ago)

    RealtimeTableSweepJob.perform_now

    assert_not Game.exists?(game.id)
  end

  test "keeps a table whose opener left the dashboard recently" do
    game = table(users(:paula))
    users(:paula).update!(dashboard_seen_at: 2.minutes.ago)

    RealtimeTableSweepJob.perform_now

    assert Game.exists?(game.id)
  end

  test "keeps a table while the opener is on the dashboard" do
    game = table(users(:paula))
    users(:paula).update!(dashboard_seen_at: 1.hour.ago)
    Presence.create!(user: users(:paula), kind: "dashboard", connection_id: "d", last_ping_at: Time.current)

    RealtimeTableSweepJob.perform_now

    assert Game.exists?(game.id)
  end

  test "a hidden table survives while its opener is online in another game" do
    game = table(users(:paula))
    busy = Game.create!(state: "playing", realtime: true)
    busy.add_player(users(:paula))
    busy.add_player(users(:jules))
    users(:paula).update!(dashboard_seen_at: 1.hour.ago)
    Presence.create!(user: users(:paula), kind: "site", connection_id: "s", last_ping_at: Time.current)

    RealtimeTableSweepJob.perform_now

    assert Game.exists?(game.id)
  end

  test "a hidden table is deleted once its opener has been offline 10+ minutes" do
    game = table(users(:paula))
    busy = Game.create!(state: "playing", realtime: true)
    busy.add_player(users(:paula))
    busy.add_player(users(:jules))
    users(:paula).update!(last_seen_at: 11.minutes.ago, dashboard_seen_at: 1.hour.ago)

    RealtimeTableSweepJob.perform_now

    assert_not Game.exists?(game.id)
  end

  test "stale presence rows are swept" do
    Presence.create!(user: users(:paula), kind: "site", connection_id: "s", last_ping_at: 5.minutes.ago)

    RealtimeTableSweepJob.perform_now

    assert_equal 0, Presence.count
  end
end
