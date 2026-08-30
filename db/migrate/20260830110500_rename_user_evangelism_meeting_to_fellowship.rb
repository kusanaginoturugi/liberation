class RenameUserEvangelismMeetingToFellowship < ActiveRecord::Migration[8.1]
  def change
    rename_column :users, :evangelism_meeting_id, :fellowship_id if column_exists?(:users, :evangelism_meeting_id)
  end
end
