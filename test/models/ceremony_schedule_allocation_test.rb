require "test_helper"

class CeremonyScheduleAllocationTest < ActiveSupport::TestCase
  setup do
    @region = Region.create!(name: "共通")
    @event = Event.create!(name: "第75次超抜式")
    EventDetail.create!(event: @event, region: @region, total_serial_count: 1650)
    @meeting = Fellowship.create!(name: "大江戸", color_code: "#C8C4C1", region: @region)
    @other_meeting = Fellowship.create!(name: "お台場", color_code: "#111111", region: @region)
    CeremonySchedule.create!(
      event: @event, fellowship: @meeting, ceremony_at: Time.zone.local(2026, 10, 1, 10),
      place: "大江戸会館", assistant_count: 1, spirit_count: 20
    )
    CeremonySchedule.create!(
      event: @event, fellowship: @meeting, ceremony_at: Time.zone.local(2026, 10, 2, 10),
      place: "大江戸会館", assistant_count: 1, spirit_count: 10
    )
  end

  test "allocation must match the fellowship scheduled spirit total" do
    allocation = CeremonyScheduleAllocation.new(event: @event, fellowship: @meeting, serial_number_from: 1, serial_number_to: 30)

    assert_predicate allocation, :valid?
    assert_equal 30, allocation.allocated_count
  end

  test "allocation rejects a count different from the fellowship scheduled spirit total" do
    allocation = CeremonyScheduleAllocation.new(event: @event, fellowship: @meeting, serial_number_from: 1, serial_number_to: 29)

    assert_not allocation.valid?
    assert_includes allocation.errors.full_messages.join, "霊数合計"
  end

  test "allocations cannot overlap" do
    CeremonySchedule.create!(
      event: @event, fellowship: @other_meeting, ceremony_at: Time.zone.local(2026, 10, 3, 10),
      place: "お台場会館", assistant_count: 1, spirit_count: 10
    )
    CeremonyScheduleAllocation.create!(event: @event, fellowship: @meeting, serial_number_from: 1, serial_number_to: 30)
    allocation = CeremonyScheduleAllocation.new(event: @event, fellowship: @other_meeting, serial_number_from: 25, serial_number_to: 34)

    assert_not allocation.valid?
    assert_includes allocation.errors.full_messages.join, "重複"
  end
end
