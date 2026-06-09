# frozen_string_literal: true

class RenameEvangelismMeetingsToFellowships < ActiveRecord::Migration[8.0]
  def change
    rename_table :evangelism_meetings, :fellowships
    rename_column :chobatsu_reports, :evangelism_meeting_id, :fellowship_id
  end
end
