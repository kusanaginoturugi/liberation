class EvangelismMeeting < ApplicationRecord
  has_many :chobatsu_reports, dependent: :restrict_with_exception

  scope :active, -> { where(active: true) }
  scope :display_sorted, -> { order(:display_order, :id) }

  validates :name, presence: true, uniqueness: true
  validates :color_code, presence: true, format: { with: /\A#[0-9A-Fa-f]{6}\z/ }
  validates :display_order, numericality: { only_integer: true, allow_nil: true }
end
