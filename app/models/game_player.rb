# == Schema Information
#
# Table name: game_players
#
#  id         :bigint           not null, primary key
#  hand       :json
#  order      :integer
#  supply     :json
#  taken_from :json
#  tiles      :json
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  game_id    :integer          not null
#  user_id    :integer          not null
#
# Indexes
#
#  index_game_players_on_game_id  (game_id)
#  index_game_players_on_user_id  (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (game_id => games.id)
#  fk_rails_...  (user_id => users.id)
#
class GamePlayer < ApplicationRecord
  belongs_to :game
  belongs_to :player, foreign_key: :user_id, class_name: "User"

  has_many :moves, dependent: :destroy

  scope :in_player_order, -> { order(order: :asc) }

  def has_taken_from?(r, c)
    JSON.parse(taken_from || "[]").include?("#{r}, #{c}")
  end

  def take_from!(r, c)
    return if has_taken_from?(r, c)
    update(taken_from: (JSON.parse(taken_from || "[]") << "#{r}, #{c}").to_json)
  end
end
