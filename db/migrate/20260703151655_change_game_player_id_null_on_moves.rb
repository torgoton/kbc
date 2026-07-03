class ChangeGamePlayerIdNullOnMoves < ActiveRecord::Migration[8.1]
  def change
    change_column_null :moves, :game_player_id, true
  end
end
