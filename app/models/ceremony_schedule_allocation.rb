class CeremonyScheduleAllocation < ApplicationRecord
  class DistributionError < StandardError; end

  belongs_to :event
  belongs_to :fellowship

  validates :fellowship_id, uniqueness: { scope: :event_id }
  validates :spirit_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :does_not_exceed_event_total

  def self.allocated_spirit_count_for(event)
    scheduled_counts = CeremonySchedule.where(event:).group(:fellowship_id).sum(:spirit_count)
    allocation_counts = where(event:).pluck(:fellowship_id, :spirit_count).to_h
    (scheduled_counts.keys | allocation_counts.keys).sum do |fellowship_id|
      allocation_counts.fetch(fellowship_id, scheduled_counts.fetch(fellowship_id, 0))
    end
  end

  def self.distribute_shortfall!(event:, qualified_spirit_count:)
    current_total = allocated_spirit_count_for(event)
    shortfall = qualified_spirit_count - current_total
    return { shortfall:, distributed: false } unless shortfall.positive?

    fellowships = Fellowship.available.where("altar_count > 0").to_a
    raise DistributionError, "壇数が設定された伝道会がありません" if fellowships.empty?

    total_altar_count = fellowships.sum(&:altar_count)
    additions = fellowships.to_h { |fellowship| [ fellowship.id, shortfall * fellowship.altar_count / total_altar_count ] }
    undistributed_count = shortfall - additions.values.sum
    fellowship_order = Fellowship::AVAILABLE_NAMES.each_with_index.to_h

    fellowships
      .sort_by do |fellowship|
        remainder = shortfall * fellowship.altar_count % total_altar_count
        [ -remainder, fellowship_order.fetch(fellowship.name) ]
      end
      .first(undistributed_count)
      .each { |fellowship| additions[fellowship.id] += 1 }

    transaction do
      fellowships.each do |fellowship|
        allocation = find_or_initialize_by(event:, fellowship:)
        allocation.spirit_count = allocation.spirit_count || CeremonySchedule.where(event:, fellowship:).sum(:spirit_count)
        allocation.update!(spirit_count: allocation.spirit_count + additions.fetch(fellowship.id))
      end
    end

    { shortfall:, distributed: true }
  end

  private

  def does_not_exceed_event_total
    return if event.blank? || fellowship.blank? || spirit_count.blank?

    total_serial_count = EventDetail.find_by(event:, region: fellowship.region)&.total_serial_count
    return if total_serial_count.blank?

    allocation_counts = self.class.where(event:).pluck(:fellowship_id, :spirit_count).to_h
    allocation_counts[fellowship_id] = spirit_count
    scheduled_counts = CeremonySchedule.where(event:).group(:fellowship_id).sum(:spirit_count)
    allocated_count = (scheduled_counts.keys | allocation_counts.keys).sum do |scheduled_fellowship_id|
      allocation_counts.fetch(scheduled_fellowship_id, scheduled_counts.fetch(scheduled_fellowship_id, 0))
    end
    return if allocated_count <= total_serial_count

    errors.add(:spirit_count, "の合計は合格霊数(#{total_serial_count})以下にしてください")
  end
end
