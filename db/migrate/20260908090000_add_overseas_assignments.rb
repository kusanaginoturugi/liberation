class AddOverseasAssignments < ActiveRecord::Migration[8.1]
  def change
    remove_index :overseas_chobatsu_entries, name: "idx_overseas_entries_event_number"
    rename_column :overseas_chobatsu_entries, :serial_number, :input_order
    add_index :overseas_chobatsu_entries, [ :event_id, :input_order ], name: "idx_overseas_entries_event_order"

    create_table :overseas_chobatsu_assignments do |t|
      t.references :event, null: false, foreign_key: true
      t.references :overseas_chobatsu_entry, null: false, foreign_key: true, index: { name: "idx_overseas_assignments_entry" }
      t.integer :serial_number, null: false

      t.timestamps
    end

    add_index :overseas_chobatsu_assignments, [ :event_id, :serial_number ], unique: true,
      name: "idx_overseas_assignments_event_number"
  end
end
