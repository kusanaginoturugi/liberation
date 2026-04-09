class ReplaceCountWithTotalSerialCountOnEventDetails < ActiveRecord::Migration[8.0]
  def up
    add_column :event_details, :total_serial_count, :integer, null: false, default: 1667
    remove_column :event_details, :count, :integer
  end

  def down
    add_column :event_details, :count, :integer, null: false, default: 0
    remove_column :event_details, :total_serial_count, :integer
  end
end
