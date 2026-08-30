class CreateCeremonyScheduleAllocations < ActiveRecord::Migration[8.1]
  def change
    create_table :ceremony_schedule_allocations do |t|
      t.references :event, null: false, foreign_key: true
      t.references :fellowship, null: false, foreign_key: true
      t.integer :serial_number_from, null: false
      t.integer :serial_number_to, null: false
      t.timestamps
    end

    add_index :ceremony_schedule_allocations, [ :event_id, :fellowship_id ], unique: true, name: "idx_schedule_allocations_event_fellowship"
  end
end
