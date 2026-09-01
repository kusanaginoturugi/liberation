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

  test "distributes a shortfall by altar count and excludes zero altar fellowships" do
    odaiba = Fellowship.create!(name: "お台場", color_code: "#111111", region: @region)
    seimeiouin = Fellowship.create!(name: "聖明王院", color_code: "#222222", region: @region)
    CeremonySchedule.create!(
      event: @event, fellowship: odaiba, ceremony_at: Time.zone.local(2026, 10, 2, 10),
      place: "お台場会館", assistant_count: 1, spirit_count: 20
    )
    CeremonySchedule.create!(
      event: @event, fellowship: seimeiouin, ceremony_at: Time.zone.local(2026, 10, 3, 10),
      place: "聖明王院", assistant_count: 1, spirit_count: 10
    )

    result = CeremonyScheduleAllocation.distribute_shortfall!(event: @event, qualified_spirit_count: 100)

    assert_equal 50, result[:shortfall]
    assert result[:distributed]
    assert_equal 37, CeremonyScheduleAllocation.find_by!(event: @event, fellowship: @meeting).spirit_count
    assert_equal 53, CeremonyScheduleAllocation.find_by!(event: @event, fellowship: odaiba).spirit_count
    assert_nil CeremonyScheduleAllocation.find_by(event: @event, fellowship: seimeiouin)
    assert_equal 100, CeremonyScheduleAllocation.allocated_spirit_count_for(@event)
  end

  test "restores the allocation values from before distribution" do
    CeremonyScheduleAllocation.create!(event: @event, fellowship: @meeting, spirit_count: 25)

    CeremonyScheduleAllocation.distribute_shortfall!(event: @event, qualified_spirit_count: 100)
    CeremonyScheduleAllocation.undo_distribution!(event: @event)

    assert_equal 25, CeremonyScheduleAllocation.find_by!(event: @event, fellowship: @meeting).spirit_count
    assert_nil CeremonyScheduleAllocationSnapshot.find_by(event: @event)
  end
end
