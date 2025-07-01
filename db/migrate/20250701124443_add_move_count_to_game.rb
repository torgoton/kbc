class AddMoveCountToGame < ActiveRecord::Migration[8.0]
  def change
    add_column :games, :move_count, :integer
  end
end
