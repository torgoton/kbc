class AddDecreeToGames < ActiveRecord::Migration[8.1]
  def change
    add_column :games, :decree, :json
  end
end
