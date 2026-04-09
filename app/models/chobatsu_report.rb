class ChobatsuReport < ApplicationRecord
  belongs_to :evangelism_meeting

  before_validation :assign_merit_fee_total

  validates :ceremony_date, :assistant_name, :participant_count, :serial_number_from, :serial_number_to, presence: true
  validates :participant_count, :merit_fee_total,
            numericality: { only_integer: true, greater_than_or_equal_to: 0, allow_nil: true }
  validates :serial_number_from, :serial_number_to,
            numericality: { only_integer: true, greater_than: 0, allow_nil: true }
  validate :serial_number_range_is_valid
  validate :serial_number_range_is_within_total
  validate :serial_number_range_does_not_overlap

  def usage_count
    return 0 if serial_number_from.blank? || serial_number_to.blank?

    serial_number_to - serial_number_from + 1
  end

  def calculated_merit_fee_total
    return 0 if participant_count.blank?

    participant_count * 5000
  end

  private

  def assign_merit_fee_total
    self.merit_fee_total = calculated_merit_fee_total
  end

  def serial_number_range_is_valid
    return if serial_number_from.blank? || serial_number_to.blank?
    return if serial_number_to >= serial_number_from

    errors.add(:serial_number_to, "は使用修霊番号(始)以上を入力してください")
  end

  def serial_number_range_is_within_total
    return if serial_number_to.blank?

    total_count = SystemSetting.total_serial_count
    return if serial_number_to <= total_count

    errors.add(:serial_number_to, "は修霊合計数(#{total_count})以下を入力してください")
  rescue ActiveRecord::RecordNotFound
    errors.add(:base, "修霊合計数の設定が見つかりません")
  end

  def serial_number_range_does_not_overlap
    return if serial_number_from.blank? || serial_number_to.blank? || evangelism_meeting.blank?

    overlap = self.class
                  .where.not(id:)
                  .joins(:evangelism_meeting)
                  .where(evangelism_meetings: { region_id: evangelism_meeting.region_id })
                  .where("serial_number_from <= ? AND serial_number_to >= ?", serial_number_to, serial_number_from)
                  .first
    return if overlap.blank?

    errors.add(:base, "使用修霊番号が既存データと重複しています (#{overlap.serial_number_from}〜#{overlap.serial_number_to})")
  end
end
