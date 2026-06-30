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
