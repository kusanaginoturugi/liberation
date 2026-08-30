class RenameCeremonyScheduleEvangelismMeetingToFellowship < ActiveRecord::Migration[8.1]
  def change
    rename_column :ceremony_schedules, :evangelism_meeting_id, :fellowship_id if column_exists?(:ceremony_schedules, :evangelism_meeting_id)
  end
end
