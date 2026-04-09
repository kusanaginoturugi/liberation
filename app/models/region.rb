class Region < ApplicationRecord
  has_many :users, dependent: :restrict_with_exception
  has_many :evangelism_meetings, dependent: :restrict_with_exception

  validates :name, presence: true, uniqueness: true
end
