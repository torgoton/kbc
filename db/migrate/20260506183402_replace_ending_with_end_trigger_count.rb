class ReplaceEndingWithEndTriggerCount < ActiveRecord::Migration[8.1]
  def change
    remove_column :games, :ending, :boolean, default: false, null: false
    add_column :games, :end_trigger_count, :integer, default: 0, null: false
  end
end
