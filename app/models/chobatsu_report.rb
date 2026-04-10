class ChobatsuReport < ApplicationRecord
  belongs_to :region
  belongs_to :event
  belongs_to :user, optional: true
  belongs_to :evangelism_meeting

  before_validation :assign_region_from_meeting
  before_validation :assign_merit_fee_total

  validates :ceremony_date, :participant_count, :serial_number_from, :serial_number_to, presence: true
  validates :participant_count, :merit_fee_total, :noah_card_count,
            numericality: { only_integer: true, greater_than_or_equal_to: 0, allow_nil: true }
  validates :serial_number_from, :serial_number_to,
            numericality: { only_integer: true, greater_than: 0, allow_nil: true }
  validates :event, :region, presence: true
  validate :serial_number_range_is_valid
  validate :serial_number_range_is_within_total
  validate :region_matches_evangelism_meeting
  validate :serial_number_range_does_not_overlap

  def usage_count
    return 0 if serial_number_from.blank? || serial_number_to.blank?

    serial_number_to - serial_number_from + 1
  end

  def calculated_merit_fee_total
    usage_count * 5000
  end

  def mirokuji_share
    (calculated_merit_fee_total * 0.65).to_i
  end

  def region_refund
    (calculated_merit_fee_total * 0.15).to_i
  end

  private

  def assign_region_from_meeting
    self.region = evangelism_meeting.region if evangelism_meeting.present?
  end

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

    total_count = event_detail_total_serial_count
    return if serial_number_to <= total_count

    errors.add(:serial_number_to, "は修霊合計数(#{total_count})以下を入力してください")
  rescue ActiveRecord::RecordNotFound
    errors.add(:base, "超抜式ごとの修霊合計数設定が見つかりません")
  end

  def serial_number_range_does_not_overlap
    return if serial_number_from.blank? || serial_number_to.blank? || region.blank? || event.blank?

    overlap = self.class
                  .where.not(id:)
                  .where(region_id: region_id, event_id: event_id)
                  .where("serial_number_from <= ? AND serial_number_to >= ?", serial_number_to, serial_number_from)
                  .first
    return if overlap.blank?

    errors.add(:base, "使用修霊番号が既存データと重複しています (#{overlap.serial_number_from}〜#{overlap.serial_number_to})")
  end

  def region_matches_evangelism_meeting
    return if evangelism_meeting.blank? || region.blank?
    return if evangelism_meeting.region_id == region_id

    errors.add(:region, "は伝道会の聖院と一致させてください")
  end

  def event_detail_total_serial_count
    EventDetail.find_by!(event_id: event_id, region_id: region_id).total_serial_count
  end
end
