class AddUserFields < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :handle, :string, null: false
    add_column :users, :approved, :boolean, default: false
    add_index :users, :handle, unique: true
  end
end
