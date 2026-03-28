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

  def settlements_remaining
    supply["settlements"].to_i
  end

  def settlements_remaining?
    settlements_remaining > 0
  end

  def decrement_supply!
    supply["settlements"] -= 1
  end

  def increment_supply!
    supply["settlements"] += 1
  end

  def held_tile_locations
    (tiles || []).map { |t| t["from"] }.to_set
  end

  def mark_tile_used!(klass)
    idx = (tiles || []).find_index { |t| t["klass"] == klass && !t["used"] }
    return unless idx
    updated = tiles.dup
    updated[idx] = updated[idx].merge("used" => true)
    self.tiles = updated
  end

  def reset_tiles!
    self.tiles = (tiles || []).map { |t| t.merge("used" => false) }
  end

  def receive_tile!(klass, from:)
    self.tiles = (tiles || []) + [ { "klass" => klass, "from" => from, "used" => true } ]
  end

  def remove_tile_from!(from)
    self.tiles = (tiles || []).reject { |t| t["from"] == from }
  end

  def restore_tile!(klass, from:, used:)
    self.tiles = (tiles || []) + [ { "klass" => klass, "from" => from, "used" => used } ]
  end

  def find_unused_tile(klass)
    (tiles || []).find { |t| t["klass"] == klass && !t["used"] }
  end

  def mark_tile_unused!(klass)
    idx = (tiles || []).find_index { |t| t["klass"] == klass && t["used"] }
    return unless idx
    updated = tiles.dup
    updated[idx] = updated[idx].merge("used" => false)
    self.tiles = updated
  end
end
