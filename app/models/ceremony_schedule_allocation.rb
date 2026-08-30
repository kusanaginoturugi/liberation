class CeremonyScheduleAllocation < ApplicationRecord
  belongs_to :event
  belongs_to :fellowship

  validates :fellowship_id, uniqueness: { scope: :event_id }
  validates :serial_number_from, :serial_number_to,
            numericality: { only_integer: true, greater_than: 0 }
  validate :end_number_is_not_before_start
  validate :matches_scheduled_spirit_count
  validate :is_within_event_total
  validate :does_not_overlap_other_allocations

  def allocated_count
    serial_number_to - serial_number_from + 1
  end

  private

  def end_number_is_not_before_start
    return if serial_number_from.blank? || serial_number_to.blank? || serial_number_to >= serial_number_from

    errors.add(:serial_number_to, "は始の番号以上を入力してください")
  end

  def matches_scheduled_spirit_count
    return if serial_number_from.blank? || serial_number_to.blank? || fellowship.blank? || event.blank?
    return if allocated_count == CeremonySchedule.where(event:, fellowship:).sum(:spirit_count)

    errors.add(:base, "番号の件数は予定表の霊数合計と一致させてください")
  end

  def is_within_event_total
    return if serial_number_to.blank? || fellowship.blank? || event.blank?

    total = EventDetail.find_by(event:, region: fellowship.region)&.total_serial_count
    return if total.blank? || serial_number_to <= total

    errors.add(:serial_number_to, "は修霊合計数(#{total})以下を入力してください")
  end

  def does_not_overlap_other_allocations
    return if serial_number_from.blank? || serial_number_to.blank? || event.blank?

    overlap = self.class.where(event:).where.not(id:)
                        .where("serial_number_from <= ? AND serial_number_to >= ?", serial_number_to, serial_number_from)
                        .exists?
    errors.add(:base, "ほかの伝道会に割り振った番号と重複しています") if overlap
  end
end
