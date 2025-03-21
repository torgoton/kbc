class CreateGames < ActiveRecord::Migration[8.0]
  def change
    create_table :games do |t|
      t.json :boards
      t.json :board_contents
      t.json :scores
      t.json :deck
      t.json :goals
      t.belongs_to :current_player, foreign_key: :game_player_id, class_name: "GamePlayer"
      t.string :state
      t.timestamps
    end
  end
end
