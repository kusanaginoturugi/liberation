class ChobatsuReportFellowship < ApplicationRecord
  belongs_to :chobatsu_report
  belongs_to :fellowship
  has_many :additional_serial_number_ranges,
           class_name: "ChobatsuReportFellowshipSerialNumberRange",
           dependent: :destroy

  before_validation :fill_end_number

  validates :participant_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :serial_number_from, :serial_number_to,
            numericality: { only_integer: true, greater_than: 0 }
  validate :serial_number_range_is_valid

  def number_ranges
    [ [ serial_number_from, serial_number_to ] ] + additional_serial_number_ranges.reject(&:marked_for_destruction?).map do |range|
      [ range.serial_number_from, range.serial_number_to ]
    end
  end

  def usage_count
    number_ranges.sum { |from, to| from.present? && to.present? ? to - from + 1 : 0 }
  end

  private

  def fill_end_number
    self.serial_number_to = serial_number_from if serial_number_to.blank? && serial_number_from.present?
  end

  def serial_number_range_is_valid
    return if serial_number_from.blank? || serial_number_to.blank?
    return if serial_number_to >= serial_number_from

    errors.add(:serial_number_to, "は使用修霊番号(始)以上を入力してください")
  end
end
