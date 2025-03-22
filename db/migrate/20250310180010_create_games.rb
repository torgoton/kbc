class CreateGames < ActiveRecord::Migration[8.0]
  def change
    create_table :games do |t|
      t.json :boards
      t.json :board_contents
      t.json :scores
      t.json :deck
      t.json :goals
      t.references :current_player
      t.string :state
      t.timestamps
    end
  end
end
