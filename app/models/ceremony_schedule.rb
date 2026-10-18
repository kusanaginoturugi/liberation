class CeremonySchedule < ApplicationRecord
  SPECIAL_SCHEDULE_NAME = "聖泉珠院・海外".freeze

  belongs_to :fellowship, optional: true
  belongs_to :event
  has_many :ceremony_schedule_fellowships, dependent: :destroy
  has_one :chobatsu_report, dependent: :restrict_with_exception

  validates :ceremony_at, :place, presence: true
  validates :fellowship, :assistant_count, :spirit_count, presence: true, unless: :special_schedule?
  validates :assistant_count, :spirit_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :serial_number_from, :serial_number_to,
            numericality: { only_integer: true, greater_than_or_equal_to: 1 }, allow_nil: true
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
    return unless special_schedule?
    return if [ serial_number_from, serial_number_to ].all?(&:blank?) && seisenjuin_serial_numbers.empty? && legacy_seisenjuin_number_range_empty?

    overseas_spirit_count + seisenjuin_spirit_count
  end

  def overseas_spirit_count
    serial_number_range_total(serial_number_from, serial_number_to)
  end

  def seisenjuin_spirit_count
    return seisenjuin_serial_numbers.size if seisenjuin_serial_numbers.present?

    serial_number_range_total(seisenjuin_serial_number_from, seisenjuin_serial_number_to)
  end

  def special_spirit_breakdown
    return [] unless special_schedule?

    [ [ "海外", overseas_spirit_count ], [ "聖泉珠院", seisenjuin_spirit_count ] ]
  end

  def seisenjuin_serial_numbers
    JSON.parse(self[:seisenjuin_serial_numbers].presence || "[]").filter_map do |number|
      parsed_number = Integer(number, exception: false)
      parsed_number if parsed_number&.positive?
    end
  end

  def seisenjuin_serial_numbers=(numbers)
    values = Array(numbers).filter_map do |number|
      parsed_number = Integer(number, exception: false)
      parsed_number if parsed_number&.positive?
    end
    self[:seisenjuin_serial_numbers] = values.uniq.to_json
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

    validate_serial_number_range_is_complete(:serial_number_from, :serial_number_to, "海外番号")
  end

  def special_serial_number_range_is_in_order
    return unless special_schedule?

    validate_serial_number_range_is_in_order(:serial_number_from, :serial_number_to, "海外番号")
  end

  def joint_schedule_is_not_special_schedule
    return unless joint_schedule? && special_schedule?

    errors.add(:base, "合同予定と聖泉珠院・海外は同時に登録できません")
  end

  def serial_number_range_total(from, to)
    return 0 unless from && to

    to - from + 1
  end

  def legacy_seisenjuin_number_range_empty?
    seisenjuin_serial_number_from.blank? && seisenjuin_serial_number_to.blank?
  end

  def validate_serial_number_range_is_complete(from_attribute, to_attribute, label)
    return if public_send(from_attribute).blank? == public_send(to_attribute).blank?

    errors.add(:base, "#{label}の始と終は両方入力してください")
  end

  def validate_serial_number_range_is_in_order(from_attribute, to_attribute, label)
    from = public_send(from_attribute)
    to = public_send(to_attribute)
    return unless from && to
    return if to >= from

    errors.add(to_attribute, "は#{label}の始の番号以上にしてください")
  end
end
