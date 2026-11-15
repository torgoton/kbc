# Runs every minute (config/recurring.yml). Two jobs:
# 1. Drops dead presence rows (crashed browsers, deploys) and announces anyone
#    who thereby went offline / left the dashboard.
# 2. Deletes open real-time tables whose opener has been away 10+ minutes.
#    "Away" means off the dashboard; but while the opener is in a playing
#    real-time game their other tables are merely hidden, and the timer only
#    runs while they are offline altogether.
class RealtimeTableSweepJob < ApplicationJob
  queue_as :default

  AWAY_CUTOFF = 10.minutes

  def perform
    sweep_presence
    delete_abandoned_tables
  end

  private

  def sweep_presence
    Presence.sweep!.each do |user_id, kind|
      user = User.find_by(id: user_id)
      PresenceBroadcaster.broadcast(user, kind) if user && !Presence.online?(user_id, kind)
    end
  end

  def delete_abandoned_tables
    Game.waiting.where(realtime: true).find_each do |game|
      opener = game.opener
      next if opener.nil? || opener.on_dashboard?
      busy = opener.in_realtime_game?
      next if busy && opener.online?
      last_here = busy ? opener.last_seen_at : opener.dashboard_seen_at
      next if last_here && last_here > AWAY_CUTOFF.ago
      game.destroy
      game.broadcast_dashboard_update
    end
  end
end
