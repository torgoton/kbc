require "test_helper"

class PresenceChannelTest < ActionCable::Channel::TestCase
  include ActiveJob::TestHelper
  tests PresenceChannel

  test "subscribed touches the current user's last_seen_at" do
    users(:chris).update!(last_seen_at: nil)
    stub_connection current_user: users(:chris)

    subscribe

    assert subscription.confirmed?
    assert_not_nil users(:chris).reload.last_seen_at
  end

  test "ping touches the current user's last_seen_at" do
    stub_connection current_user: users(:chris)
    subscribe
    users(:chris).update!(last_seen_at: 1.hour.ago)

    perform :ping

    assert_in_delta Time.current, users(:chris).reload.last_seen_at, 2.seconds
  end

  test "subscribing records a presence row of the requested kind" do
    stub_connection current_user: users(:chris)

    subscribe kind: "dashboard", connection_id: "tab-1"

    assert Presence.online?(users(:chris).id, "dashboard")
    assert_not Presence.online?(users(:chris).id, "site")
    assert_not_nil users(:chris).reload.dashboard_seen_at
  end

  test "two tabs: closing one keeps the user online" do
    stub_connection current_user: users(:chris)
    subscribe kind: "site", connection_id: "tab-1"
    Presence.create!(user: users(:chris), kind: "site", connection_id: "tab-2", last_ping_at: Time.current)

    unsubscribe

    assert users(:chris).online?
  end

  test "closing the last tab removes presence and schedules a settle broadcast" do
    stub_connection current_user: users(:chris)
    subscribe kind: "site", connection_id: "tab-1"

    assert_enqueued_with(job: PresenceSettleJob, args: [ users(:chris).id, "site" ]) { unsubscribe }

    assert_not users(:chris).online?
  end

  test "coming online broadcasts a dot swap to the presence stream" do
    stub_connection current_user: users(:chris)

    assert_broadcasts("presence", 1) { subscribe kind: "site", connection_id: "tab-1" }
  end

  test "a second tab does not re-broadcast" do
    Presence.create!(user: users(:chris), kind: "site", connection_id: "tab-1", last_ping_at: Time.current)
    stub_connection current_user: users(:chris)

    assert_no_broadcasts("presence") { subscribe kind: "site", connection_id: "tab-2" }
  end
end
