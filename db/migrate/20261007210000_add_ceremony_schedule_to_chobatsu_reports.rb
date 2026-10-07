class AddCeremonyScheduleToChobatsuReports < ActiveRecord::Migration[8.1]
  def change
    add_reference :chobatsu_reports, :ceremony_schedule, foreign_key: true, index: false
    add_index :chobatsu_reports, :ceremony_schedule_id, unique: true, where: "ceremony_schedule_id IS NOT NULL"
  end
end
