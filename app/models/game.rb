class Game < ApplicationRecord
  has_many :game_players
  has_many :players, through: :game_players
  has_one :first_player

  def add_player(user)
    players << user
  end
end
