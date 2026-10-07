class ChobatsuReportFellowshipSerialNumberRange < ApplicationRecord
  belongs_to :chobatsu_report_fellowship

  before_validation :fill_end_number

  validates :serial_number_from, :serial_number_to,
            numericality: { only_integer: true, greater_than: 0 }
  validate :serial_number_range_is_valid

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
