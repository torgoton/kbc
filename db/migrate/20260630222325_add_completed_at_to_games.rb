class AddCompletedAtToGames < ActiveRecord::Migration[8.1]
  def change
    add_column :games, :completed_at, :datetime
  end
end
