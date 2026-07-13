class CreateAnnouncements < ActiveRecord::Migration[8.1]
  def change
    create_table :announcements do |t|
      t.string :title, null: false
      t.boolean :pinned, null: false, default: false
      t.timestamps
    end
    add_index :announcements, [ :pinned, :created_at ]
  end
end
