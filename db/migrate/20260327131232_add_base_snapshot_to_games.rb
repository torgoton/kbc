class AddBaseSnapshotToGames < ActiveRecord::Migration[8.1]
  def change
    add_column :games, :base_snapshot, :jsonb
  end
end
