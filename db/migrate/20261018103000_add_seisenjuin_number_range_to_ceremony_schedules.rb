class AddSeisenjuinNumberRangeToCeremonySchedules < ActiveRecord::Migration[8.1]
  def change
    add_column :ceremony_schedules, :seisenjuin_serial_number_from, :integer
    add_column :ceremony_schedules, :seisenjuin_serial_number_to, :integer
  end
end
