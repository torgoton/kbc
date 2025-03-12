class Game < ApplicationRecord
  has_many :players, class_name: :users, through: :game_players
  has_one :first_player
end
