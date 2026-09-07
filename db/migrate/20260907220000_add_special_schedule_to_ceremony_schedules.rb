class AddSpecialScheduleToCeremonySchedules < ActiveRecord::Migration[8.1]
  def change
    add_column :ceremony_schedules, :special_schedule, :boolean, null: false, default: false
    change_column_null :ceremony_schedules, :fellowship_id, true
    change_column_null :ceremony_schedules, :assistant_count, true
    change_column_null :ceremony_schedules, :spirit_count, true
  end
end
