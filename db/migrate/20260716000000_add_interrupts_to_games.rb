class AddInterruptsToGames < ActiveRecord::Migration[8.1]
  def change
    add_column :games, :interrupts, :json, default: [], null: false
  end
end
