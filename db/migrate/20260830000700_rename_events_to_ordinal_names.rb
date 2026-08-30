class RenameEventsToOrdinalNames < ActiveRecord::Migration[8.1]
  class Event < ApplicationRecord
    self.table_name = "events"
  end

  class EventDetail < ApplicationRecord
    self.table_name = "event_details"
  end

  def up
    rename_event("第74回超抜式", "第74次超抜式")
    event = rename_event("第75回超抜式", "第75次超抜式")
    EventDetail.where(event_id: event.id).update_all(total_serial_count: 1650) if event
  end

  def down
    rename_event("第74次超抜式", "第74回超抜式")
    rename_event("第75次超抜式", "第75回超抜式")
  end

  private

  def rename_event(previous_name, new_name)
    event = Event.find_by(name: previous_name)
    return Event.find_by(name: new_name) if event.blank?

    event.update!(name: new_name)
    event
  end
end
