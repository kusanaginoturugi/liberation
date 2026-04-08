class EvangelismMeeting < ApplicationRecord
  has_many :chobatsu_reports, dependent: :restrict_with_exception

  validates :name, presence: true, uniqueness: true
  validates :color_code, presence: true, format: { with: /\A#[0-9A-Fa-f]{6}\z/ }
end
