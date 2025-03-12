class GamePlayer < ApplicationRecord
  belongs_to :game
  belongs_to :player, class_name: :user
end
