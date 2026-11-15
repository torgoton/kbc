# Runs shortly after a connection closes, then broadcasts the user's settled state.
class PresenceSettleJob < ApplicationJob
  queue_as :default

  def perform(user_id, kind)
    user = User.find_by(id: user_id)
    PresenceBroadcaster.broadcast(user, kind) if user
  end
end
