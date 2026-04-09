class EventDetail < ApplicationRecord
  belongs_to :event
  belongs_to :region

  validates :count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :region_id, uniqueness: { scope: :event_id }
end
