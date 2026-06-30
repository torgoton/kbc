class CreateChatMessages < ActiveRecord::Migration[8.1]
  def change
    create_table :chat_messages do |t|
      t.references :game, null: false, foreign_key: true
      t.references :game_player, null: true, foreign_key: true
      t.string :body, null: false

      t.timestamps
    end
  end
end
