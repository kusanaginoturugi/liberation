class CeremonyScheduleFellowship < ApplicationRecord
  belongs_to :ceremony_schedule
  belongs_to :fellowship

  validates :spirit_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
end
