class EventDetail < ApplicationRecord
  DEFAULT_TOTAL_SERIAL_COUNT = 1667

  belongs_to :event
  belongs_to :region

  validates :total_serial_count, numericality: { only_integer: true, greater_than: 0 }
  validates :region_id, uniqueness: { scope: :event_id }
end
