class AddSeisenjuinSerialNumbersToCeremonySchedules < ActiveRecord::Migration[8.1]
  def change
    add_column :ceremony_schedules, :seisenjuin_serial_numbers, :text, null: false, default: "[]"
  end
end
