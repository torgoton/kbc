class CreateMoves < ActiveRecord::Migration[8.0]
  def change
    create_table :moves do |t|
      t.belongs_to :game, null: false, foreign_key: true
      t.belongs_to :game_player, null: false, foreign_key: true
      t.integer :order
      t.string :action
      t.string :from
      t.string :to
      t.boolean :reversible
      t.string :message

      t.timestamps
    end
  end
end
