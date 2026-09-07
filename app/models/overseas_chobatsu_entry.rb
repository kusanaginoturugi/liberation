class OverseasChobatsuEntry < ApplicationRecord
  belongs_to :event
  belongs_to :fellowship

  validates :fellowship_id, uniqueness: { scope: :event_id }
  validates :spirit_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
end
