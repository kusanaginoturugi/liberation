class Event < ApplicationRecord
  has_many :event_details, dependent: :destroy
  has_many :regions, through: :event_details
  has_many :chobatsu_reports, dependent: :restrict_with_exception
  has_many :ceremony_schedules, dependent: :restrict_with_exception
  has_many :ceremony_schedule_allocations, dependent: :destroy

  validates :name, presence: true, uniqueness: true
  validate :open_event_must_remain_available
  validate :chobatsu_period_is_in_order

  scope :recent_first, -> { order(created_at: :desc, id: :desc) }
  scope :open, -> { where(closed: false) }

  private

  def open_event_must_remain_available
    return unless closed?
    return if self.class.where.not(id: id).open.exists?

    errors.add(:closed, "開催中の超抜式を1つ残してください")
  end

  def chobatsu_period_is_in_order
    return if chobatsu_starts_on.blank? || chobatsu_ends_on.blank?
    return if chobatsu_ends_on >= chobatsu_starts_on

    errors.add(:chobatsu_ends_on, "は開始日以降にしてください")
  end
end
