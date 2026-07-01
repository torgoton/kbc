class AddRatingSnapshotsToGamePlayers < ActiveRecord::Migration[8.1]
  def change
    add_column :game_players, :rating_before, :integer
    add_column :game_players, :rating_after, :integer
  end
end
