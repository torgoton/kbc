# == Schema Information
#
# Table name: moves
#
#  id         :bigint           not null, primary key
#  detail     :json
#  order      :integer
#  player     :integer
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  game_id    :integer          not null
#
# Indexes
#
#  index_moves_on_game_id  (game_id)
#
# Foreign Keys
#
#  fk_rails_...  (game_id => games.id)
#
class Move < ApplicationRecord
  belongs_to :game
  belongs_to :game_player
end
