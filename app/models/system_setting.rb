class SystemSetting < ApplicationRecord
  TOTAL_SERIAL_COUNT_KEY = "total_serial_count".freeze

  validates :key, presence: true, uniqueness: true
  validates :value, presence: true

  def self.total_serial_count
    find_by!(key: TOTAL_SERIAL_COUNT_KEY).value.to_i
  end
end
