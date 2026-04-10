class SystemSetting < ApplicationRecord
  GRADIENT_ENABLED_KEY = "gradient_enabled".freeze
  NUMBER_SHADOW_ENABLED_KEY = "number_shadow_enabled".freeze

  validates :key, presence: true, uniqueness: true
  validates :value, presence: true

  def self.gradient_enabled?
    setting = find_by(key: GRADIENT_ENABLED_KEY)
    return true if setting.blank?

    ActiveModel::Type::Boolean.new.cast(setting.value)
  end

  def self.number_shadow_enabled?
    setting = find_by(key: NUMBER_SHADOW_ENABLED_KEY)
    return false if setting.blank?

    ActiveModel::Type::Boolean.new.cast(setting.value)
  end
end
