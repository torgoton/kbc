class CreatePresences < ActiveRecord::Migration[8.1]
  def change
    create_table :presences do |t|
      t.references :user, null: false, foreign_key: true
      t.string :kind, null: false
      t.string :connection_id, null: false
      t.datetime :last_ping_at, null: false
      t.timestamps
    end
    add_index :presences, [ :connection_id, :kind ], unique: true
    add_column :users, :dashboard_seen_at, :datetime
  end
end
