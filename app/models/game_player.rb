class GamePlayer < ApplicationRecord
  belongs_to :game
  belongs_to :player, foreign_key: :user_id, class_name: "User"

  has_many :moves, dependent: :destroy

  scope :in_player_order, -> { order(order: :asc) }
end
