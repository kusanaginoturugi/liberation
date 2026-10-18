class CeremonyScheduleAllocation < ApplicationRecord
  class DistributionError < StandardError; end
  NON_DISTRIBUTION_FELLOWSHIP_NAMES = [ "聖明王院", "大仏殿" ].freeze
  FIXED_ALLOCATION_COUNTS = { "茨城" => 50 }.freeze

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
    fellowships = Fellowship.available.to_a
    scheduled_counts = scheduled_spirit_counts_for(event)
    fixed_allocation_counts = fellowships.filter_map do |fellowship|
      [ fellowship.id, FIXED_ALLOCATION_COUNTS.fetch(fellowship.name) ] if FIXED_ALLOCATION_COUNTS.key?(fellowship.name)
    end.to_h
    distributing_fellowships = fellowships
      .reject { |fellowship| fellowship.name.in?(NON_DISTRIBUTION_FELLOWSHIP_NAMES) || FIXED_ALLOCATION_COUNTS.key?(fellowship.name) }
      .select(&:altar_count?)
    raise DistributionError, "壇数が設定された伝道会がありません" if distributing_fellowships.empty?

    scheduled_total = distributing_fellowships.sum { |fellowship| scheduled_counts.fetch(fellowship.id, 0) } + fixed_allocation_counts.values.sum
    shortfall = qualified_spirit_count - scheduled_total
    raise DistributionError, "合格霊数が予定霊数を下回っています" if shortfall.negative?

    total_altar_count = distributing_fellowships.sum(&:altar_count)
    additions = distributing_fellowships.to_h { |fellowship| [ fellowship.id, shortfall * fellowship.altar_count / total_altar_count ] }
    undistributed_count = shortfall - additions.values.sum
    fellowship_order = Fellowship::AVAILABLE_NAMES.each_with_index.to_h

    distributing_fellowships
      .sort_by do |fellowship|
        remainder = shortfall * fellowship.altar_count % total_altar_count
        [ -remainder, fellowship_order.fetch(fellowship.name) ]
      end
      .first(undistributed_count)
      .each { |fellowship| additions[fellowship.id] += 1 }

    transaction do
      if !preserve_snapshot && !CeremonyScheduleAllocationSnapshot.exists?(event:)
        CeremonyScheduleAllocationSnapshot.create!(
          event:,
          allocation_counts: where(event:).pluck(:fellowship_id, :spirit_count).to_h
        )
      end

      rows = fellowships.map do |fellowship|
        spirit_count = if fellowship.name.in?(NON_DISTRIBUTION_FELLOWSHIP_NAMES)
          0
        elsif fixed_allocation_counts.key?(fellowship.id)
          fixed_allocation_counts.fetch(fellowship.id)
        elsif additions.key?(fellowship.id)
          scheduled_counts.fetch(fellowship.id, 0) + additions.fetch(fellowship.id)
        else
          scheduled_counts.fetch(fellowship.id, 0)
        end
        { event_id: event.id, fellowship_id: fellowship.id, spirit_count:, created_at: Time.current, updated_at: Time.current }
      end
      where(event:).delete_all
      insert_all!(rows)
    end

    { shortfall:, distributed: true, scheduled_total: }
  end

  def self.rebalance_for_qualified_count!(event:, qualified_spirit_count:)
    distribute_by_altar_count!(event:, qualified_spirit_count:)
  end

  def self.distribute_by_altar_count!(event:, qualified_spirit_count:, record_snapshot: false)
    fellowships = Fellowship.available.to_a
    fixed_allocation_counts = fellowships.filter_map do |fellowship|
      [ fellowship.id, FIXED_ALLOCATION_COUNTS.fetch(fellowship.name) ] if FIXED_ALLOCATION_COUNTS.key?(fellowship.name)
    end.to_h
    remaining_spirit_count = qualified_spirit_count - fixed_allocation_counts.values.sum
    raise DistributionError, "合格霊数が固定割り振り数を下回っています" if remaining_spirit_count.negative?

    distributing_fellowships = fellowships.reject { |fellowship| fellowship.name.in?(NON_DISTRIBUTION_FELLOWSHIP_NAMES) || FIXED_ALLOCATION_COUNTS.key?(fellowship.name) }.select(&:altar_count?)
    raise DistributionError, "壇数が設定された伝道会がありません" if distributing_fellowships.empty?

    total_altar_count = distributing_fellowships.sum(&:altar_count)
    allocation_counts = distributing_fellowships.to_h do |fellowship|
      [ fellowship.id, remaining_spirit_count * fellowship.altar_count / total_altar_count ]
    end
    remaining_count = remaining_spirit_count - allocation_counts.values.sum
    fellowship_order = Fellowship::AVAILABLE_NAMES.each_with_index.to_h

    distributing_fellowships
      .sort_by do |fellowship|
        remainder = remaining_spirit_count * fellowship.altar_count % total_altar_count
        [ -remainder, fellowship_order.fetch(fellowship.name) ]
      end
      .first(remaining_count)
      .each { |fellowship| allocation_counts[fellowship.id] += 1 }
    allocation_counts.merge!(fixed_allocation_counts)

    timestamp = Time.current
    rows = fellowships.map do |fellowship|
      {
        event_id: event.id,
        fellowship_id: fellowship.id,
        spirit_count: allocation_counts.fetch(fellowship.id, 0),
        created_at: timestamp,
        updated_at: timestamp
      }
    end

    transaction do
      if record_snapshot && !CeremonyScheduleAllocationSnapshot.exists?(event:)
        CeremonyScheduleAllocationSnapshot.create!(
          event:,
          allocation_counts: where(event:).pluck(:fellowship_id, :spirit_count).to_h
        )
      end

      where(event:).delete_all
      insert_all!(rows)
    end

    { rebalanced: true, distributed: true }
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

  def self.restore_scheduled_counts!(event:, qualified_spirit_count:)
    scheduled_counts = scheduled_spirit_counts_for(event)
    scheduled_total = scheduled_counts.values.sum
    return { rebalanced: false, restored: false } if qualified_spirit_count > scheduled_total

    transaction do
      adjusted_counts = scheduled_counts.dup
      remaining_reduction = scheduled_total - qualified_spirit_count
      fellowships = Fellowship.where(id: scheduled_counts.keys).index_by(&:id)
      fellowship_ids = scheduled_counts.keys.sort_by do |fellowship_id|
        [ fellowships.fetch(fellowship_id).name == "聖明王院" ? 0 : 1, fellowship_id ]
      end
      fellowship_ids.each do |fellowship_id|
        break if remaining_reduction.zero?

        reduction = [ adjusted_counts.fetch(fellowship_id), remaining_reduction ].min
        adjusted_counts[fellowship_id] -= reduction
        remaining_reduction -= reduction
      end

      where(event:).delete_all
      fellowship_ids.each do |fellowship_id|
        create!(event:, fellowship_id:, spirit_count: adjusted_counts.fetch(fellowship_id))
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
