class DropTurnClicks < ActiveRecord::Migration[8.1]
  def change
    drop_table :turn_clicks, if_exists: true
  end
end
