class OverseasChobatsuEntry < ApplicationRecord
  belongs_to :event
  belongs_to :fellowship

  validates :serial_number, :assistant_name, presence: true
  validates :serial_number, numericality: { only_integer: true, greater_than_or_equal_to: 1 }, uniqueness: { scope: :event_id }
end
