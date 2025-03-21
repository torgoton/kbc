class CreateGamePlayers < ActiveRecord::Migration[8.0]
  def change
    create_table :game_players do |t|
      t.belongs_to :game
      t.belongs_to :user
      t.json :hand
      t.json :supply
      t.json :tiles
      t.integer :order
      t.timestamps
    end
  end
end
