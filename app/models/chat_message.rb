# == Schema Information
#
# Table name: chat_messages
#
#  id             :bigint           not null, primary key
#  body           :string           not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  game_id        :bigint           not null
#  game_player_id :bigint
#
# Indexes
#
#  index_chat_messages_on_game_id         (game_id)
#  index_chat_messages_on_game_player_id  (game_player_id)
#
# Foreign Keys
#
#  fk_rails_...  (game_id => games.id)
#  fk_rails_...  (game_player_id => game_players.id)
#
class ChatMessage < ApplicationRecord
  belongs_to :game
  belongs_to :game_player, optional: true

  validates :body, presence: true, length: { maximum: 500 }

  after_create_commit :broadcast

  private

  def broadcast
    game.broadcast_append_to(
      "game_#{game.id}",
      target: "chat-messages",
      partial: "games/chat_message",
      locals: { message: self }
    )
    game.broadcast_sound("chat") if game_player_id.present?
  end
end
