class AddTimedGamesFields < ActiveRecord::Migration[8.1]
  def change
    add_column :games, :speed, :string
    add_column :games, :turn_started_at, :datetime
    add_column :game_players, :time_remaining_ms, :integer
    add_column :game_players, :clock_started_at, :datetime
    add_column :users, :last_seen_at, :datetime
  end
end
