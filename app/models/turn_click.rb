# == Schema Information
#
# Table name: turn_clicks
#
#  id           :bigint           not null, primary key
#  consequences :json             not null
#  order        :integer          not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  game_id      :bigint           not null
#
# Indexes
#
#  index_turn_clicks_on_game_id            (game_id)
#  index_turn_clicks_on_game_id_and_order  (game_id,order) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (game_id => games.id)
#
class TurnClick < ApplicationRecord
  belongs_to :game

  scope :for_game, ->(game) { where(game: game).order(order: :desc) }

  def self.most_recent_for(game)
    for_game(game).first
  end
end
