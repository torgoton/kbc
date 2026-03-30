class DashboardController < ApplicationController
  def index
    @my_games = Current.user.my_games.includes(game_players: :player)
    @waiting_games = Current.user.waiting_games.includes(game_players: :player)
    @completed_games = Current.user.completed_games.includes(game_players: :player)
  end
end
