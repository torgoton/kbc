class CreateTurnClicks < ActiveRecord::Migration[8.1]
  def change
    create_table :turn_clicks do |t|
      t.references :game, null: false, foreign_key: true
      t.integer :order, null: false
      t.json :consequences, null: false, default: []
      t.timestamps
    end
    add_index :turn_clicks, [ :game_id, :order ], unique: true
  end
end
