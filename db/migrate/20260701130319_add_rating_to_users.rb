class AddRatingToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :rating, :integer, null: false, default: 1500
  end
end
