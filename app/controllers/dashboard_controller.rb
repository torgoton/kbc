class DashboardController < ApplicationController
  def index
    @my_games = Current.user.my_games.includes(game_players: :player)
    @other_games = Game.where(state: "playing").where.not(id: Current.user.games.select(:id)).order(:id).includes(game_players: :player)
    @waiting_games = Current.user.waiting_games
    @realtime_games = Current.user.realtime_waiting_games
    @completed_games = Current.user.completed_games.includes(game_players: :player)
    @pinned_announcements = Announcement.pinned
    @latest_unpinned = Announcement.unpinned.first
  end
end
