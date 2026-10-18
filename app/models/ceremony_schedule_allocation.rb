class CeremonyScheduleAllocation < ApplicationRecord
  class DistributionError < StandardError; end

  belongs_to :event
  belongs_to :fellowship

  validates :fellowship_id, uniqueness: { scope: :event_id }
  validates :spirit_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :does_not_exceed_event_total

  def self.allocated_spirit_count_for(event)
    effective_spirit_count_for(event, where(event:).pluck(:fellowship_id, :spirit_count).to_h)
  end

  def self.distribution_additions_for(event)
    snapshot = CeremonyScheduleAllocationSnapshot.find_by(event:)
    return {} unless snapshot

    scheduled_counts = scheduled_spirit_counts_for(event)
    previous_counts = snapshot.allocation_counts
    current_counts = where(event:).pluck(:fellowship_id, :spirit_count).to_h

    (scheduled_counts.keys | previous_counts.keys | current_counts.keys).to_h do |fellowship_id|
      previous_count = previous_counts.fetch(fellowship_id, scheduled_counts.fetch(fellowship_id, 0))
      current_count = current_counts.fetch(fellowship_id, scheduled_counts.fetch(fellowship_id, 0))
      [ fellowship_id, current_count - previous_count ]
    end
  end

  def self.distribute_shortfall!(event:, qualified_spirit_count:, preserve_snapshot: false)
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
      unless preserve_snapshot
        snapshot = CeremonyScheduleAllocationSnapshot.find_or_initialize_by(event:)
        snapshot.allocation_counts = where(event:).pluck(:fellowship_id, :spirit_count).to_h
        snapshot.save!
      end

      fellowships.each do |fellowship|
        allocation = find_or_initialize_by(event:, fellowship:)
        allocation.spirit_count = allocation.spirit_count || scheduled_spirit_counts_for(event).fetch(fellowship.id, 0)
        allocation.update!(spirit_count: allocation.spirit_count + additions.fetch(fellowship.id))
      end
    end

    { shortfall:, distributed: true }
  end

  def self.rebalance_for_qualified_count!(event:, qualified_spirit_count:)
    unless allocated_spirit_count_for(event) > qualified_spirit_count
      return restore_scheduled_counts!(event:)
    end

    snapshot = CeremonyScheduleAllocationSnapshot.find_by(event:)
    unless snapshot
      trim_overflow!(event:, qualified_spirit_count:)
      return restore_scheduled_counts!(event:).merge(rebalanced: true)
    end

    transaction do
      where(event:).delete_all
      snapshot.allocation_counts.each do |fellowship_id, spirit_count|
        create!(event:, fellowship_id:, spirit_count:)
      end
      distribute_shortfall!(event:, qualified_spirit_count:, preserve_snapshot: true)
    end

    restore_scheduled_counts!(event:).merge(rebalanced: true)
  end

  def self.undo_distribution!(event:)
    snapshot = CeremonyScheduleAllocationSnapshot.find_by(event:)
    raise DistributionError, "元に戻せる配分がありません" unless snapshot

    transaction do
      where(event:).delete_all
      snapshot.allocation_counts.each do |fellowship_id, spirit_count|
        create!(event:, fellowship_id:, spirit_count:)
      end
      snapshot.destroy!
    end
  end

  private

  def self.trim_overflow!(event:, qualified_spirit_count:)
    overflow = allocated_spirit_count_for(event) - qualified_spirit_count
    scheduled_counts = scheduled_spirit_counts_for(event)
    schedule_times = CeremonySchedule.where(event:).regular.group(:fellowship_id).minimum(:ceremony_at)
    allocations = where(event:).includes(:fellowship).to_a.sort_by do |allocation|
      [
        allocation.fellowship.name == "聖明王院" ? 0 : 1,
        -schedule_times.fetch(allocation.fellowship_id, Time.utc(9999, 12, 31)).to_i,
        allocation.fellowship_id
      ]
    end

    transaction do
      allocations.each do |allocation|
        break if overflow.zero?

        reducible_count = [ allocation.spirit_count - scheduled_counts.fetch(allocation.fellowship_id, 0), 0 ].max
        reduction = [ reducible_count, overflow ].min
        next if reduction.zero?

        allocation.update!(spirit_count: allocation.spirit_count - reduction)
        overflow -= reduction
      end
    end

    { rebalanced: true }
  end

  def self.effective_spirit_count_for(event, allocation_counts)
    scheduled_counts = scheduled_spirit_counts_for(event)
    (scheduled_counts.keys | allocation_counts.keys).sum do |fellowship_id|
      allocation_counts.fetch(fellowship_id, scheduled_counts.fetch(fellowship_id, 0))
    end
  end

  def self.restore_scheduled_counts!(event:)
    scheduled_counts = scheduled_spirit_counts_for(event)
    allocations = where(event:).includes(:fellowship).index_by(&:fellowship_id)
    deficits = scheduled_counts.filter_map do |fellowship_id, scheduled_count|
      current_count = allocations[fellowship_id]&.spirit_count || scheduled_count
      [ fellowship_id, scheduled_count - current_count ] if current_count < scheduled_count
    end
    return { rebalanced: false, restored: false } if deficits.empty?

    donors = allocations.values.select do |allocation|
      allocation.spirit_count > scheduled_counts.fetch(allocation.fellowship_id, 0)
    end.sort_by do |allocation|
      [ allocation.fellowship.name == "聖明王院" ? 0 : 1, allocation.fellowship_id ]
    end
    return { rebalanced: false, restored: false } if donors.empty?

    transaction do
      deficits.each do |fellowship_id, deficit|
        recipient = allocations[fellowship_id] || find_or_create_by!(event:, fellowship_id:) do |allocation|
          allocation.spirit_count = scheduled_counts.fetch(fellowship_id)
        end

        donors.each do |donor|
          break if deficit.zero?

          donor_floor = scheduled_counts.fetch(donor.fellowship_id, 0)
          transfer = [ donor.spirit_count - donor_floor, deficit ].min
          next unless transfer.positive?

          donor.update!(spirit_count: donor.spirit_count - transfer)
          recipient.update!(spirit_count: recipient.spirit_count + transfer)
          deficit -= transfer
        end
      end
    end

    { rebalanced: false, restored: true }
  end

  def self.scheduled_spirit_counts_for(event)
    CeremonySchedule.where(event:).regular.includes(ceremony_schedule_fellowships: :fellowship).each_with_object(Hash.new(0)) do |schedule, counts|
      schedule.allocation_contributions.each do |fellowship, spirit_count|
        counts[fellowship.id] += spirit_count
      end
    end
  end

  def does_not_exceed_event_total
    return if event.blank? || fellowship.blank? || spirit_count.blank?

    total_serial_count = EventDetail.find_by(event:, region: fellowship.region)&.total_serial_count
    return if total_serial_count.blank?

    allocation_counts = self.class.where(event:).pluck(:fellowship_id, :spirit_count).to_h
    allocation_counts[fellowship_id] = spirit_count
    scheduled_counts = self.class.send(:scheduled_spirit_counts_for, event)
    allocated_count = (scheduled_counts.keys | allocation_counts.keys).sum do |scheduled_fellowship_id|
      allocation_counts.fetch(scheduled_fellowship_id, scheduled_counts.fetch(scheduled_fellowship_id, 0))
    end
    return if allocated_count <= total_serial_count

    errors.add(:spirit_count, "の合計は合格霊数(#{total_serial_count})以下にしてください")
  end
end
