class Fellowship < ApplicationRecord
  belongs_to :region
  has_many :chobatsu_reports, dependent: :restrict_with_exception

  scope :active, -> { where(active: true) }
  scope :enabled, -> { where(enabled: true) }
  scope :display_sorted, -> { order(:display_order, :id) }

  validates :name, presence: true, uniqueness: true
  validates :color_code, format: { with: /\A#[0-9A-Fa-f]{6}\z/ }, allow_nil: true
  validates :display_order, numericality: { only_integer: true, allow_nil: true }
end
