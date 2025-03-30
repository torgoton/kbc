class Move < ApplicationRecord
  belongs_to :game
  belongs_to :game_player
end
