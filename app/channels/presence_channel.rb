# Tracks whether a logged-in user is online. We don't enumerate raw server
# connections (per-process, unreliable across deploys/restarts); instead
# subscribing and each client heartbeat (see presence_controller.js) touch
# users.last_seen_at, and User#online? reads that timestamp.
class PresenceChannel < ApplicationCable::Channel
  def subscribed
    touch_last_seen
  end

  def ping
    touch_last_seen
  end

  private

  def touch_last_seen
    current_user.update_column(:last_seen_at, Time.current)
  end
end
