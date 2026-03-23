class AddCurrentActionToGames < ActiveRecord::Migration[8.1]
  def change
    add_column :games, :current_action, :json, default: { name: "none" }
  end
end
