class CeremonyScheduleAllocation < ApplicationRecord
  belongs_to :event
  belongs_to :fellowship

  validates :fellowship_id, uniqueness: { scope: :event_id }
  validates :spirit_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :does_not_exceed_event_total

  private

  def does_not_exceed_event_total
    return if event.blank? || fellowship.blank? || spirit_count.blank?

    total_serial_count = EventDetail.find_by(event:, region: fellowship.region)&.total_serial_count
    return if total_serial_count.blank?

    overrides = self.class.where(event:).where.not(id:).pluck(:fellowship_id, :spirit_count).to_h
    allocated_count = CeremonySchedule.where(event:).group(:fellowship_id).sum(:spirit_count).sum do |fellowship_id, scheduled_count|
      fellowship_id == self.fellowship_id ? spirit_count : overrides.fetch(fellowship_id, scheduled_count)
    end
    return if allocated_count <= total_serial_count

    errors.add(:spirit_count, "の合計は合格霊数(#{total_serial_count})以下にしてください")
  end
end
