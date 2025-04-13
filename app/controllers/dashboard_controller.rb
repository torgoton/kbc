class DashboardController < ApplicationController
  def index
    @my_games = Current.user.games
    @other_games = (GamePlayer.joins(:game).
      where("game_players.user_id != ?", Current.user.id).
      map(&:game).
      uniq.
      sort_by(&:id)) - @my_games
  end
end
