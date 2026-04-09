class Region < ApplicationRecord
  has_many :users, dependent: :restrict_with_exception
  has_many :evangelism_meetings, dependent: :restrict_with_exception
  has_many :event_details, dependent: :restrict_with_exception
  has_many :events, through: :event_details
  has_many :chobatsu_reports, dependent: :restrict_with_exception

  validates :name, presence: true, uniqueness: true
end
