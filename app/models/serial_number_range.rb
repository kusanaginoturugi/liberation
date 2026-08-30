class SerialNumberRange < ApplicationRecord
  belongs_to :chobatsu_report

  before_validation :fill_end_number

  validates :serial_number_from, :serial_number_to, presence: true
  validates :serial_number_from, :serial_number_to, numericality: { only_integer: true, greater_than: 0 }
  validate :end_number_is_not_before_start

  def usage_count
    serial_number_to - serial_number_from + 1
  end

  private

  def fill_end_number
    self.serial_number_to = serial_number_from if serial_number_to.blank? && serial_number_from.present?
  end

  def end_number_is_not_before_start
    return if serial_number_from.blank? || serial_number_to.blank? || serial_number_to >= serial_number_from

    errors.add(:serial_number_to, "は始の番号以上を入力してください")
  end
end
