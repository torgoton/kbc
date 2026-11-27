# For an external uptime monitor. /up stays 200 when Solid Cable's listener
# thread dies, which silently stops all live updates until a restart.
class CableHealthController < ActionController::Base
  def show
    # The listener is created on first subscribe, so none yet is healthy.
    # ponytail: reads Solid Cable internals and only sees this Puma process;
    # a stuck-but-alive thread passes. Use an end-to-end canary if that happens.
    listener = ActionCable.server.pubsub.instance_variable_get(:@listener)
    dead = listener && !listener.instance_variable_get(:@thread).alive?
    head dead ? :service_unavailable : :ok
  end
end
