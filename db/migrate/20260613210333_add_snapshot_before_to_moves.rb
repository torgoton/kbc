class AddSnapshotBeforeToMoves < ActiveRecord::Migration[8.1]
  def change
    add_column :moves, :snapshot_before, :jsonb
  end
end
