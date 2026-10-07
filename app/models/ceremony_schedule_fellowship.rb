class CeremonyScheduleFellowship < ApplicationRecord
  belongs_to :ceremony_schedule
  belongs_to :fellowship

  validates :assistant_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :spirit_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
end
