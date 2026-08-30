class CeremonySchedule < ApplicationRecord
  belongs_to :fellowship

  validates :ceremony_at, :place, :assistant_count, :spirit_count, presence: true
  validates :assistant_count, :spirit_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  scope :chronological, -> { includes(:fellowship).order(:ceremony_at, :id) }
end
