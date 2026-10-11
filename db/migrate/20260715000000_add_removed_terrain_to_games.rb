class AddRemovedTerrainToGames < ActiveRecord::Migration[8.1]
  def change
    add_column :games, :removed_terrain, :string
  end
end
