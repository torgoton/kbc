class AddReversibleToTurnClicks < ActiveRecord::Migration[8.1]
  def change
    add_column :turn_clicks, :reversible, :boolean, null: false, default: true
  end
end
