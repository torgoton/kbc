class CreateMoves < ActiveRecord::Migration[8.0]
  def change
    create_table :moves do |t|
      t.belongs_to :game, null: false, foreign_key: true
      t.integer :order
      t.integer :player
      t.json :detail

      t.timestamps
    end
  end
end
