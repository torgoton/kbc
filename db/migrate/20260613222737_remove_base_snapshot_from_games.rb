class RemoveBaseSnapshotFromGames < ActiveRecord::Migration[8.1]
  def change
    remove_column :games, :base_snapshot, :jsonb
  end
end
