require "test_helper"

class CeremonyScheduleAllocationTest < ActiveSupport::TestCase
  setup do
    @region = Region.create!(name: "共通")
    @event = Event.create!(name: "第75次超抜式")
    EventDetail.create!(event: @event, region: @region, total_serial_count: 100)
    @meeting = Fellowship.create!(name: "大江戸", color_code: "#C8C4C1", region: @region)
    CeremonySchedule.create!(
      event: @event, fellowship: @meeting, ceremony_at: Time.zone.local(2026, 10, 1, 10),
      place: "大江戸会館", assistant_count: 1, spirit_count: 20
    )
  end

  test "allows an allocation count different from the scheduled count" do
    allocation = CeremonyScheduleAllocation.new(event: @event, fellowship: @meeting, spirit_count: 25)

    assert_predicate allocation, :valid?
  end

  test "allocation total cannot exceed the event total" do
    allocation = CeremonyScheduleAllocation.new(event: @event, fellowship: @meeting, spirit_count: 101)

    assert_not allocation.valid?
    assert_includes allocation.errors[:spirit_count].join, "100"
  end
end
