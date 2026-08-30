class AddEventToCeremonySchedules < ActiveRecord::Migration[8.1]
  class Event < ApplicationRecord
    self.table_name = "events"
  end

  class EventDetail < ApplicationRecord
    self.table_name = "event_details"
  end

  class Region < ApplicationRecord
    self.table_name = "regions"
  end

  class CeremonySchedule < ApplicationRecord
    self.table_name = "ceremony_schedules"
  end

  def up
    add_reference :ceremony_schedules, :event, foreign_key: true

    previous_event = Event.find_by(name: "第74回超抜式")
    event = Event.find_or_create_by!(name: "第75回超抜式") do |record|
      record.closed = false
    end
    event.update!(closed: false)
    Event.where.not(id: event.id).update_all(closed: true)

    Region.find_each do |region|
      previous_detail = EventDetail.find_by(event_id: previous_event&.id, region_id: region.id)
      EventDetail.find_or_create_by!(event_id: event.id, region_id: region.id) do |detail|
        detail.total_serial_count = previous_detail&.total_serial_count || 1667
      end
    end

    CeremonySchedule.update_all(event_id: event.id)
    change_column_null :ceremony_schedules, :event_id, false
  end

  def down
    remove_reference :ceremony_schedules, :event, foreign_key: true
  end
end
