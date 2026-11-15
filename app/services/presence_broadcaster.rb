# Pushes presence changes to open pages.
# - site: swap the user's online dots everywhere (all pages follow stream "presence").
# - dashboard: re-render the real-time tables for people looking at the dashboard,
#   since a table is listed only while its creator is on the dashboard.
module PresenceBroadcaster
  def self.broadcast(user, kind)
    if kind == "dashboard"
      broadcast_realtime_tables
    else
      Turbo::StreamsChannel.broadcast_replace_to(
        "presence", targets: ".presence-#{user.id}",
        partial: "shared/presence_dot", locals: { user: user }
      )
    end
  end

  def self.broadcast_realtime_tables
    User.where(id: Presence.online_user_ids("dashboard"), approved: true).find_each do |viewer|
      Turbo::StreamsChannel.broadcast_update_to(
        "user_#{viewer.id}", target: "dashboard-realtime-games",
        partial: "dashboard/realtime_games",
        locals: { games: viewer.realtime_waiting_games, viewer: viewer }
      )
    end
  end
end
