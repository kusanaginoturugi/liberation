class ChobatsuReport < ApplicationRecord
  belongs_to :region
  belongs_to :event
  belongs_to :user, optional: true
  belongs_to :fellowship
  has_many :serial_number_ranges, dependent: :destroy
  accepts_nested_attributes_for :serial_number_ranges, allow_destroy: true, reject_if: :all_blank

  before_validation :assign_region_from_meeting
  before_validation :assign_merit_fee_total
  before_validation :fill_end_number

  validates :ceremony_date, :participant_count, :serial_number_from, presence: true
  validates :participant_count, :merit_fee_total, :noah_card_count,
            numericality: { only_integer: true, greater_than_or_equal_to: 0, allow_nil: true }
  validates :serial_number_from, :serial_number_to,
            numericality: { only_integer: true, greater_than: 0, allow_nil: true }
  validates :event, :region, presence: true
  validate :serial_number_range_is_valid
  validate :serial_number_range_is_within_total
  validate :region_matches_fellowship
  validate :serial_number_range_does_not_overlap
  validate :event_is_open, on: :create

  def usage_count
    number_ranges.sum { |from, to| from.present? && to.present? ? to - from + 1 : 0 }
  end

  def number_ranges
    [ [ serial_number_from, serial_number_to ] ] + serial_number_ranges.reject(&:marked_for_destruction?).map { |range| [ range.serial_number_from, range.serial_number_to ] }
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
    self.region = fellowship.region if fellowship.present?
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
    total_count = event_detail_total_serial_count
    number_ranges.each do |from, to|
      next if from.blank? || to.blank? || to <= total_count

      errors.add(:serial_number_to, "は合格霊数(#{total_count})以下を入力してください")
    end
  rescue ActiveRecord::RecordNotFound
    errors.add(:base, "超抜式ごとの合格霊数設定が見つかりません")
  end

  def serial_number_range_does_not_overlap
    return if region.blank? || event.blank?

    ranges = number_ranges
    return if ranges.any? { |from, to| from.blank? || to.blank? }
    if ranges.combination(2).any? { |left, right| left.first <= right.last && left.last >= right.first }
      errors.add(:base, "同じ報告内で使用修霊番号が重複しています")
      return
    end

    overlap = self.class.where.not(id:).where(region_id: region_id, event_id: event_id).includes(:serial_number_ranges).find do |report|
      ranges.any? { |range| report.number_ranges.any? { |other| range.first <= other.last && range.last >= other.first } }
    end
    errors.add(:base, "使用修霊番号が既存データと重複しています") if overlap
  end

  def region_matches_fellowship
    return if fellowship.blank? || region.blank?
    return if fellowship.region_id == region_id

    errors.add(:region, "は伝道会の聖院と一致させてください")
  end

  def event_is_open
    return unless event&.closed?

    errors.add(:event, "は終了した超抜式のため登録できません")
  end

  def event_detail_total_serial_count
    EventDetail.find_by!(event_id: event_id, region_id: region_id).total_serial_count
  end

  def fill_end_number
    self.serial_number_to = serial_number_from if serial_number_to.blank? && serial_number_from.present?
  end
end
