class RebalanceOpenAllocationsForDaibutsudenCount < ActiveRecord::Migration[8.1]
  def up
    Event.joins(:ceremony_schedules).merge(CeremonySchedule.regular).where(closed: false).distinct.find_each do |event|
      detail = event.event_details.find_by(region: Region.order(:id).first)
      next unless detail

      CeremonyScheduleAllocation.rebalance_for_qualified_count!(
        event:,
        qualified_spirit_count: detail.total_serial_count
      )
    end
  end

  def down
  end
end
