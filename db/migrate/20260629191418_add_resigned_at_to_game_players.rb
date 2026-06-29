class AddResignedAtToGamePlayers < ActiveRecord::Migration[8.1]
  def change
    add_column :game_players, :resigned_at, :datetime
  end
end
