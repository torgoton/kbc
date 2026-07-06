require "test_helper"

class PresenceChannelTest < ActionCable::Channel::TestCase
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
end
