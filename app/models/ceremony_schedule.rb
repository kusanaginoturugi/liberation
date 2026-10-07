class CeremonySchedule < ApplicationRecord
  SPECIAL_SCHEDULE_NAME = "聖泉珠院・海外".freeze

  belongs_to :fellowship, optional: true
  belongs_to :event
  has_many :ceremony_schedule_fellowships, dependent: :destroy
  has_one :chobatsu_report, dependent: :restrict_with_exception

  validates :ceremony_at, :place, presence: true
  validates :fellowship, :assistant_count, :spirit_count, presence: true, unless: :special_schedule?
  validates :assistant_count, :spirit_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :serial_number_from, :serial_number_to, numericality: { only_integer: true, greater_than_or_equal_to: 1 }, allow_nil: true
  validates :event_id, uniqueness: { conditions: -> { where(special_schedule: true) } }, if: :special_schedule?
  validate :special_serial_number_range_is_complete
  validate :special_serial_number_range_is_in_order
  validate :joint_schedule_is_not_special_schedule

  before_validation :assign_special_spirit_count

  scope :chronological, -> { includes(:chobatsu_report, :fellowship, ceremony_schedule_fellowships: :fellowship).order(:ceremony_at, :id) }
  scope :for_event, ->(event) { where(event: event) }
  scope :regular, -> { where(special_schedule: false) }
  scope :special, -> { where(special_schedule: true) }

  def display_name
    return SPECIAL_SCHEDULE_NAME if special_schedule?
    return fellowship.name unless joint_schedule?

    joint_contributions.map { |contribution| contribution.fellowship.name }.join("・") + "（合同）"
  end

  def joint_spirit_breakdown
    return unless joint_schedule?

    joint_contributions.map { |contribution| "#{contribution.fellowship.name}#{contribution.spirit_count}" }.join("・")
  end

  def joint_assistant_breakdown
    return unless joint_schedule?

    joint_assistant_breakdown_lines.join("・")
  end

  def joint_assistant_breakdown_lines
    return [] unless joint_schedule?

    joint_contributions.map do |contribution|
      "#{contribution.fellowship.name}#{contribution.assistant_count || "-"}"
    end
  end

  def joint_spirit_breakdown_lines
    return [] unless joint_schedule?

    joint_contributions.map { |contribution| "#{contribution.fellowship.name}#{contribution.spirit_count}" }
  end

  def joint_fellowship_counts
    return [] unless joint_schedule?

    joint_contributions.map do |contribution|
      {
        name: contribution.fellowship.name,
        assistant_count: contribution.assistant_count,
        spirit_count: contribution.spirit_count
      }
    end
  end

  def allocation_contributions
    return [ [ fellowship, spirit_count ] ] unless joint_schedule?

    joint_contributions.map { |contribution| [ contribution.fellowship, contribution.spirit_count ] }
  end

  def joint_primary_spirit_count
    joint_contribution_for(fellowship)&.spirit_count
  end

  def joint_primary_assistant_count
    joint_contribution_for(fellowship)&.assistant_count
  end

  def joint_secondary_fellowship
    joint_contributions.find { |contribution| contribution.fellowship_id != fellowship_id }&.fellowship
  end

  def joint_secondary_spirit_count
    joint_contributions.find { |contribution| contribution.fellowship_id != fellowship_id }&.spirit_count
  end

  def joint_secondary_assistant_count
    joint_contributions.find { |contribution| contribution.fellowship_id != fellowship_id }&.assistant_count
  end

  def special_spirit_total
    return unless serial_number_from && serial_number_to

    serial_number_to - serial_number_from + 1
  end

  private

  def joint_contributions
    ceremony_schedule_fellowships.sort_by { |contribution| contribution.fellowship_id == fellowship_id ? 0 : 1 }
  end

  def joint_contribution_for(target_fellowship)
    return unless target_fellowship

    joint_contributions.find { |contribution| contribution.fellowship_id == target_fellowship.id }
  end

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

  def joint_schedule_is_not_special_schedule
    return unless joint_schedule? && special_schedule?

    errors.add(:base, "合同予定と聖泉珠院・海外は同時に登録できません")
  end
end
