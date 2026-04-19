# == Schema Information
#
# Table name: moves
#
#  id             :bigint           not null, primary key
#  action         :string
#  deliberate     :boolean
#  from           :string
#  message        :string
#  order          :integer
#  payload        :jsonb
#  reversible     :boolean
#  to             :string
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  game_id        :bigint           not null
#  game_player_id :bigint           not null
#
# Indexes
#
#  index_moves_on_game_id         (game_id)
#  index_moves_on_game_player_id  (game_player_id)
#
# Foreign Keys
#
#  fk_rails_...  (game_id => games.id)
#  fk_rails_...  (game_player_id => game_players.id)
#
class Move < ApplicationRecord
  SOUNDS = {
    "build"             => "build",
    "select_settlement" => "select_settlement",
    "move_settlement"   => "move",
    "pick_up_tile"      => "tile_pickup",
    "forfeit_tile"      => "tile_forfeit",
    "end_turn"          => "end_turn",
    "end_game"          => "game_end",
    "remove_settlement" => "removed",
    "activate_outpost"  => "outpost",
    "place_wall"        => "wall"
  }.freeze

  belongs_to :game
  belongs_to :game_player

  after_create_commit :broadcast_sound

  private

  def broadcast_sound
    game.broadcast_sound(sound_key)
  end

  def sound_key
    return SOUNDS[action] if SOUNDS.key?(action)
    payload["klass"].delete_suffix("Tile").downcase if action == "select_action" && payload&.dig("klass")
  end
end
