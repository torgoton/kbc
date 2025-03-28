class GamePlayer < ApplicationRecord
  belongs_to :game
  belongs_to :player, foreign_key: :user_id, class_name: "User"

  scope :in_player_order, -> { order(order: :asc) }
end
