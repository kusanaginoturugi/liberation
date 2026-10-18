class ApplyScheduledCountsToExistingAllocations < ActiveRecord::Migration[8.1]
  def up
    EventDetail.find_each do |detail|
      CeremonyScheduleAllocation.rebalance_for_qualified_count!(
        event: detail.event,
        qualified_spirit_count: detail.total_serial_count
      )
    end
  end

  def down
  end
end
