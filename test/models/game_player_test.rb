# == Schema Information
#
# Table name: game_players
#
#  id         :bigint           not null, primary key
#  hand       :json
#  order      :integer
#  supply     :json
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
require "test_helper"

class GamePlayerTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
