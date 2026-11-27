require "test_helper"
require "action_cable/subscription_adapter/solid_cable"

# Uses a real Solid Cable adapter, so a gem upgrade that moves the listener
# internals the check reads fails here.
class CableHealthControllerTest < ActionDispatch::IntegrationTest
  setup do
    adapter = @adapter = ActionCable::SubscriptionAdapter::SolidCable.new(ActionCable.server)
    ActionCable.server.define_singleton_method(:pubsub) { adapter }
  end

  teardown { ActionCable.server.singleton_class.remove_method(:pubsub) }

  test "ok before anything has subscribed" do
    get "/up/cable"
    assert_response :ok
  end

  test "ok while the listener thread is running" do
    @adapter.send(:listener)
    get "/up/cable"
    assert_response :ok
    @adapter.shutdown
  end

  test "unavailable once the listener thread has died" do
    @adapter.send(:listener).send(:thread).kill.join
    get "/up/cable"
    assert_response :service_unavailable
  end
end
