class AddScoresAfterToMoves < ActiveRecord::Migration[8.1]
  def change
    add_column :moves, :scores_after, :jsonb
  end
end
