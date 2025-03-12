class CreateGames < ActiveRecord::Migration[8.0]
  def change
    create_table :games do |t|
      t.json :boards
      t.json :board_contents
      t.json :scores
      t.json :deck
      t.json :goals
      t.string :state
      t.belongs_to :user # first player
      t.timestamps
    end
  end
end
