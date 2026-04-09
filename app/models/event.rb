class Event < ApplicationRecord
  has_many :event_details, dependent: :destroy
  has_many :regions, through: :event_details
  has_many :chobatsu_reports, dependent: :restrict_with_exception

  validates :name, presence: true, uniqueness: true

  scope :recent_first, -> { order(created_at: :desc, id: :desc) }
end
