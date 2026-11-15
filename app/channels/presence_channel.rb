# Tracks who is online and who is on the dashboard. Each open page subscribes
# with a `kind` ("site" for every page, "dashboard" for the dashboard) and a
# per-page `connection_id`; Presence rows are the source of truth, so several
# tabs count correctly. Heartbeats keep the row fresh (stale rows are swept),
# and state changes are broadcast so dots and real-time tables update live.
class PresenceChannel < ApplicationCable::Channel
  SETTLE_DELAY = 5.seconds

  def subscribed
    @kind = Presence::KINDS.include?(params[:kind]) ? params[:kind] : "site"
    @connection_id = params[:connection_id].presence || SecureRandom.uuid
    was_present = Presence.online?(current_user.id, @kind)
    touch_row
    PresenceBroadcaster.broadcast(current_user, @kind) unless was_present
  end

  def ping
    was_present = Presence.online?(current_user.id, @kind)
    touch_row
    PresenceBroadcaster.broadcast(current_user, @kind) unless was_present
  end

  def unsubscribed
    Presence.where(connection_id: @connection_id, kind: @kind).delete_all
    stamp_user
    # Reloads and page navigations drop and re-open the connection within
    # moments; only announce "gone" if they haven't come back.
    PresenceSettleJob.set(wait: SETTLE_DELAY).perform_later(current_user.id, @kind)
  end

  private

  def touch_row
    row = Presence.find_or_initialize_by(connection_id: @connection_id, kind: @kind)
    row.update!(user: current_user, last_ping_at: Time.current)
    stamp_user
  end

  # last_seen_at feeds the timed-game sweep; dashboard_seen_at the real-time table cleanup.
  def stamp_user
    column = @kind == "dashboard" ? :dashboard_seen_at : :last_seen_at
    current_user.update_column(column, Time.current)
  end
end
