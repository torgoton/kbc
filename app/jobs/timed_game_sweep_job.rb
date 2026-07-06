# Runs every minute (see config/recurring.yml) so timed games close
# themselves when nobody is watching. Three unattended fallbacks, all
# scoped to timed games only (untimed tables/games are never touched):
#
# 1. A current player flagged (live bank <= 0) for 10+ minutes gets
#    auto-resigned — the claim-victory flow can't help if no opponent is
#    there to claim it.
# 2. A waiting table whose opener has been offline 10+ minutes is deleted;
#    nobody can join a table with no one to start it.
# 3. A playing game whose current player never started their clock and has
#    been offline 10+ minutes is cancelled (no penalty) — a hostage game
#    the flag rule can't reach, since their clock was never running.
class TimedGameSweepJob < ApplicationJob
  queue_as :default

  FLAG_RESIGN_THRESHOLD_MS = -600_000
  OFFLINE_CUTOFF = 10.minutes

  def perform
    resign_long_flagged_players
    delete_stale_waiting_tables
    cancel_abandoned_games
  end

  private

  def resign_long_flagged_players
    Game.playing.where.not(speed: nil).find_each do |game|
      current = game.current_player
      next unless current
      next if game.time_remaining_for(current) > FLAG_RESIGN_THRESHOLD_MS
      current.resign!(message: "#{current.player.handle} ran out of time", deliberate: false)
    end
  end

  def delete_stale_waiting_tables
    Game.waiting.where.not(speed: nil).find_each do |game|
      opener = game.game_players.first&.player
      next unless opener && offline_for_at_least?(opener, OFFLINE_CUTOFF)
      game.destroy
      game.broadcast_dashboard_update
    end
  end

  def cancel_abandoned_games
    Game.playing.where.not(speed: nil).find_each do |game|
      current = game.current_player
      next unless current && current.clock_started_at.nil?
      next unless offline_for_at_least?(current.player, OFFLINE_CUTOFF)
      game.destroy
      game.broadcast_dashboard_update
    end
  end

  def offline_for_at_least?(user, duration)
    user.last_seen_at.nil? || user.last_seen_at < duration.ago
  end
end
