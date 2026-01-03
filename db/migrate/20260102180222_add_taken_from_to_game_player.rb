class AddTakenFromToGamePlayer < ActiveRecord::Migration[8.1]
  def change
    add_column :game_players, :taken_from, :json
  end
end
