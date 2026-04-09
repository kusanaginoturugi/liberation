class AddRegionToEvangelismMeetings < ActiveRecord::Migration[8.0]
  class Region < ApplicationRecord
    self.table_name = "regions"
  end

  class EvangelismMeeting < ApplicationRecord
    self.table_name = "evangelism_meetings"
  end

  def up
    add_reference :evangelism_meetings, :region, foreign_key: true

    default_region = Region.find_or_create_by!(name: "共通")
    EvangelismMeeting.update_all(region_id: default_region.id)

    change_column_null :evangelism_meetings, :region_id, false
  end

  def down
    remove_reference :evangelism_meetings, :region, foreign_key: true
  end
end
