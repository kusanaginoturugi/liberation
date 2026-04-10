class Event < ApplicationRecord
  has_many :event_details, dependent: :destroy
  has_many :regions, through: :event_details
  has_many :chobatsu_reports, dependent: :restrict_with_exception

  validates :name, presence: true, uniqueness: true
  validate :open_event_must_remain_available

  scope :recent_first, -> { order(created_at: :desc, id: :desc) }
  scope :open, -> { where(closed: false) }

  private

  def open_event_must_remain_available
    return unless closed?
    return if self.class.where.not(id: id).open.exists?

    errors.add(:closed, "開催中の超抜式を1つ残してください")
  end
end
