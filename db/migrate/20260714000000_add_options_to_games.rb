class AddOptionsToGames < ActiveRecord::Migration[8.1]
  def change
    add_column :games, :options, :json, default: {}, null: false
  end
end
