class DashboardController < ApplicationController
  def index
    @my_games = Current.user.games
    @open_games = Game.joins(:game_players).where(state: "waiting").where.not(game_players: { user_id: Current.user.id }).sort_by(&:id)
  end
end
