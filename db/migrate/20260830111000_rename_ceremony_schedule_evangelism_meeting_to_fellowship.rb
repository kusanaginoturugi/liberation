class RenameCeremonyScheduleEvangelismMeetingToFellowship < ActiveRecord::Migration[8.1]
  def change
    rename_column :ceremony_schedules, :evangelism_meeting_id, :fellowship_id
  end
end
