class AllowBlankCeremonyScheduleMinister < ActiveRecord::Migration[8.1]
  def change
    change_column_null :ceremony_schedules, :minister_name, true
  end
end
