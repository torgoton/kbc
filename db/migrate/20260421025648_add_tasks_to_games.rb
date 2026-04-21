class AddTasksToGames < ActiveRecord::Migration[8.1]
  def change
    add_column :games, :tasks, :json
  end
end
