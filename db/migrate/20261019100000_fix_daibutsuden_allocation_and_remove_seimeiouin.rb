class FixDaibutsudenAllocationAndRemoveSeimeiouin < ActiveRecord::Migration[8.1]
  def up
    seimeiouin = Fellowship.find_by(name: "聖明王院")
    CeremonyScheduleAllocation.where(fellowship: seimeiouin).delete_all if seimeiouin

    if seimeiouin
      CeremonyScheduleAllocationSnapshot.find_each do |snapshot|
        counts = snapshot.allocation_counts
        next unless counts.delete(seimeiouin.id)

        snapshot.update!(allocation_counts: counts)
      end
    end

    Event.joins(:ceremony_schedules).merge(CeremonySchedule.regular).where(closed: false).distinct.find_each do |event|
      detail = event.event_details.find_by(region: Region.order(:id).first)
      next unless detail

      CeremonyScheduleAllocation.distribute_shortfall!(
        event:,
        qualified_spirit_count: detail.total_serial_count,
        preserve_snapshot: true
      )
    end
  end

  def down
  end
end
