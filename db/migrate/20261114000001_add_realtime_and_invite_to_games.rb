class AddRealtimeAndInviteToGames < ActiveRecord::Migration[8.1]
  def change
    add_column :games, :realtime, :boolean, default: false, null: false
    add_reference :games, :invited_user, null: true, foreign_key: { to_table: :users }
  end
end
