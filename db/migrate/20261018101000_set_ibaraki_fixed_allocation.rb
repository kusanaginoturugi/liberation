class SetIbarakiFixedAllocation < ActiveRecord::Migration[8.1]
  def up
    EventDetail.find_each do |detail|
      CeremonyScheduleAllocation.distribute_by_altar_count!(
        event: detail.event,
        qualified_spirit_count: detail.total_serial_count
      )
    end
  end

  def down
  end
end
