class DashboardController < ApplicationController
  def index
    @other_games = GamePlayer.joins(:game).
      where("game_players.user_id != ?", Current.user.id).
      map(&:game).
      uniq.
      sort_by(&:id)
  end
end
