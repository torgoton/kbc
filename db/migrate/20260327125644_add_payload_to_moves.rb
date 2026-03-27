class AddPayloadToMoves < ActiveRecord::Migration[8.1]
  def change
    add_column :moves, :payload, :jsonb
  end
end
