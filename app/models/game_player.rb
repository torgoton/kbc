# == Schema Information
#
# Table name: game_players
#
#  id           :bigint           not null, primary key
#  bonus_scores :jsonb            not null
#  hand         :json
#  order        :integer
#  supply       :json
#  taken_from   :json
#  tiles        :json
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  game_id      :integer          not null
#  user_id      :integer          not null
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

  def warriors_remaining
    supply["warriors"].to_i
  end

  def warriors_remaining?
    warriors_remaining > 0
  end

  def add_warriors!(n)
    supply["warriors"] = warriors_remaining + n
  end

  def decrement_warrior_supply!
    supply["warriors"] = warriors_remaining - 1
  end

  def increment_warrior_supply!
    supply["warriors"] = warriors_remaining + 1
  end

  def ships_remaining
    supply["ships"].to_i
  end

  def ships_remaining?
    ships_remaining > 0
  end

  def add_ships!(n)
    supply["ships"] = ships_remaining + n
  end

  def decrement_ship_supply!
    supply["ships"] = ships_remaining - 1
  end

  def increment_ship_supply!
    supply["ships"] = ships_remaining + 1
  end

  def wagons_remaining
    supply["wagons"].to_i
  end

  def wagons_remaining?
    wagons_remaining > 0
  end

  def add_wagons!(n)
    supply["wagons"] = wagons_remaining + n
  end

  def decrement_wagon_supply!
    supply["wagons"] = wagons_remaining - 1
  end

  def increment_wagon_supply!
    supply["wagons"] = wagons_remaining + 1
  end

  def return_piece_to_supply!(meeple)
    case meeple
    when "warrior" then increment_warrior_supply!
    when "ship"    then increment_ship_supply!
    when "wagon"   then increment_wagon_supply!
    else                increment_supply!
    end
  end

  def remove_piece_from_supply!(meeple)
    case meeple
    when "warrior" then decrement_warrior_supply!
    when "ship"    then decrement_ship_supply!
    when "wagon"   then decrement_wagon_supply!
    else                decrement_supply!
    end
  end

  def city_halls_remaining
    supply["city_halls"].to_i
  end

  def city_halls_remaining?
    city_halls_remaining > 0
  end

  def add_city_halls!(n)
    supply["city_halls"] = city_halls_remaining + n
  end

  def decrement_city_hall_supply!
    supply["city_halls"] = city_halls_remaining - 1
  end

  def increment_city_hall_supply!
    supply["city_halls"] = city_halls_remaining + 1
  end

  def supply_hash
    {
      "warrior"   => warriors_remaining,
      "ship"      => ships_remaining,
      "wagon"     => wagons_remaining,
      "city_hall" => city_halls_remaining
    }
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

  def mark_tile_permanently_used!(klass)
    idx = (tiles || []).find_index { |t| t["klass"] == klass && !t["used"] }
    return unless idx
    updated = tiles.dup
    updated[idx] = updated[idx].merge("used" => true, "permanent" => true)
    self.tiles = updated
  end

  def mark_tile_unpermanent!(klass)
    idx = (tiles || []).find_index { |t| t["klass"] == klass && t["permanent"] }
    return unless idx
    updated = tiles.dup
    updated[idx] = updated[idx].except("permanent").merge("used" => false)
    self.tiles = updated
  end

  def reset_tiles!
    self.tiles = (tiles || []).map { |t| t["permanent"] ? t : t.merge("used" => false) }
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
