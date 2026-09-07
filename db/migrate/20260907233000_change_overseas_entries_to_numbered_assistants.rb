class ChangeOverseasEntriesToNumberedAssistants < ActiveRecord::Migration[8.1]
  def change
    add_column :ceremony_schedules, :serial_number_from, :integer
    add_column :ceremony_schedules, :serial_number_to, :integer

    remove_index :overseas_chobatsu_entries, name: "idx_overseas_entries_event_fellowship"
    remove_column :overseas_chobatsu_entries, :spirit_count, :integer
    add_column :overseas_chobatsu_entries, :serial_number, :integer
    execute "DELETE FROM overseas_chobatsu_entries"
    add_index :overseas_chobatsu_entries, [ :event_id, :serial_number ], unique: true,
      name: "idx_overseas_entries_event_number"
  end
end
