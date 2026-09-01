class CreateCeremonyScheduleAllocationSnapshots < ActiveRecord::Migration[8.1]
  def change
    create_table :ceremony_schedule_allocation_snapshots do |t|
      t.references :event, null: false, foreign_key: true, index: { unique: true }
      t.text :allocation_counts, null: false, default: "{}"

      t.timestamps
    end
  end
end
