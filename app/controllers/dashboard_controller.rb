class DashboardController < ApplicationController
  def index
    @my_games = Current.user.my_games
    @waiting_games = Current.user.waiting_games
    @completed_games = Current.user.completed_games
  end
end
