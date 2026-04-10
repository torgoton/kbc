class AddNomadsColumns < ActiveRecord::Migration[8.1]
  def change
    add_column :games, :stone_walls, :integer, default: 25, null: false
    add_column :games, :turn_number, :integer, default: 0, null: false
    add_column :game_players, :bonus_scores, :jsonb, default: {}, null: false
  end
end
