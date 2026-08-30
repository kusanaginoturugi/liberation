class RemoveCeremonyScheduleAllocations < ActiveRecord::Migration[8.1]
  def change
    drop_table :ceremony_schedule_allocations
  end
end
