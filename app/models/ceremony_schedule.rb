class CeremonySchedule < ApplicationRecord
  SPECIAL_SCHEDULE_NAME = "聖泉珠院・海外".freeze

  belongs_to :fellowship, optional: true
  belongs_to :event

  validates :ceremony_at, :place, presence: true
  validates :fellowship, :assistant_count, :spirit_count, presence: true, unless: :special_schedule?
  validates :assistant_count, :spirit_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :serial_number_from, :serial_number_to, numericality: { only_integer: true, greater_than_or_equal_to: 1 }, allow_nil: true
  validates :event_id, uniqueness: { conditions: -> { where(special_schedule: true) } }, if: :special_schedule?
  validate :special_serial_number_range_is_complete
  validate :special_serial_number_range_is_in_order

  before_validation :assign_special_spirit_count

  scope :chronological, -> { includes(:fellowship).order(:ceremony_at, :id) }
  scope :for_event, ->(event) { where(event: event) }
  scope :regular, -> { where(special_schedule: false) }
  scope :special, -> { where(special_schedule: true) }

  def display_name
    special_schedule? ? SPECIAL_SCHEDULE_NAME : fellowship.name
  end

  def special_spirit_total
    return unless serial_number_from && serial_number_to

    serial_number_to - serial_number_from + 1
  end

  private

  def assign_special_spirit_count
    self.spirit_count = special_spirit_total if special_schedule?
  end

  def special_serial_number_range_is_complete
    return unless special_schedule?
    return if serial_number_from.blank? == serial_number_to.blank?

    errors.add(:base, "番号の始と終は両方入力してください")
  end

  def special_serial_number_range_is_in_order
    return unless special_schedule? && serial_number_from && serial_number_to
    return if serial_number_to >= serial_number_from

    errors.add(:serial_number_to, "は始の番号以上にしてください")
  end
end
