class GamePlayer < ApplicationRecord
  belongs_to :game
  belongs_to :player, foreign_key: :user_id, class_name: "User"
end
