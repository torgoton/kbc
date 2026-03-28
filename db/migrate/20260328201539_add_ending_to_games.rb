class AddEndingToGames < ActiveRecord::Migration[8.1]
  def change
    add_column :games, :ending, :boolean, default: false, null: false
  end
end
