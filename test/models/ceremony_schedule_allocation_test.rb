require "test_helper"

class CeremonyScheduleAllocationTest < ActiveSupport::TestCase
  setup do
    @region = Region.create!(name: "共通")
    @event = Event.create!(name: "第75次修霊超抜式")
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

    assert_equal 60, result[:shortfall]
    assert result[:distributed]
    assert_equal 40, CeremonyScheduleAllocation.find_by!(event: @event, fellowship: @meeting).spirit_count
    assert_equal 60, CeremonyScheduleAllocation.find_by!(event: @event, fellowship: odaiba).spirit_count
    assert_equal 0, CeremonyScheduleAllocation.find_by!(event: @event, fellowship: seimeiouin).spirit_count
    assert_equal 100, CeremonyScheduleAllocation.allocated_spirit_count_for(@event)
    assert_equal 20, CeremonyScheduleAllocation.distribution_additions_for(@event).fetch(@meeting.id)
    assert_equal 40, CeremonyScheduleAllocation.distribution_additions_for(@event).fetch(odaiba.id)
  end

  test "restores the allocation values from before distribution" do
    CeremonyScheduleAllocation.create!(event: @event, fellowship: @meeting, spirit_count: 25)

    CeremonyScheduleAllocation.distribute_shortfall!(event: @event, qualified_spirit_count: 100)
    CeremonyScheduleAllocation.undo_distribution!(event: @event)

    assert_equal 25, CeremonyScheduleAllocation.find_by!(event: @event, fellowship: @meeting).spirit_count
    assert_nil CeremonyScheduleAllocationSnapshot.find_by(event: @event)
    assert_empty CeremonyScheduleAllocation.distribution_additions_for(@event)
  end

  test "rebalances by altar count when the qualified spirit count is lowered" do
    odaiba = Fellowship.create!(name: "お台場", color_code: "#111111", region: @region)
    CeremonySchedule.create!(
      event: @event, fellowship: odaiba, ceremony_at: Time.zone.local(2026, 10, 2, 10),
      place: "お台場会館", assistant_count: 1, spirit_count: 20
    )
    CeremonyScheduleAllocation.distribute_shortfall!(event: @event, qualified_spirit_count: 100)

    result = CeremonyScheduleAllocation.rebalance_for_qualified_count!(event: @event, qualified_spirit_count: 92)

    assert result[:rebalanced]
    assert_equal 92, CeremonyScheduleAllocation.allocated_spirit_count_for(@event)
    assert_equal 31, CeremonyScheduleAllocation.find_by!(event: @event, fellowship: @meeting).spirit_count
    assert_equal 61, CeremonyScheduleAllocation.find_by!(event: @event, fellowship: odaiba).spirit_count
  end

  test "rebalances by altar count when a prior distribution snapshot is unavailable" do
    odaiba = Fellowship.create!(name: "お台場", color_code: "#111111", region: @region)
    CeremonySchedule.create!(
      event: @event, fellowship: odaiba, ceremony_at: Time.zone.local(2026, 10, 2, 10),
      place: "お台場会館", assistant_count: 1, spirit_count: 20
    )
    CeremonyScheduleAllocation.create!(event: @event, fellowship: @meeting, spirit_count: 50)
    CeremonyScheduleAllocation.create!(event: @event, fellowship: odaiba, spirit_count: 50)
    @event.event_details.find_by!(region: @region).update!(total_serial_count: 92)

    result = CeremonyScheduleAllocation.rebalance_for_qualified_count!(event: @event, qualified_spirit_count: 92)

    assert result[:rebalanced]
    assert_equal 92, CeremonyScheduleAllocation.allocated_spirit_count_for(@event)
    assert_equal 61, CeremonyScheduleAllocation.find_by!(event: @event, fellowship: odaiba).spirit_count
  end

  test "sets Seimeioin and Daibutsuden allocations to zero and keeps Ibaraki at fifty" do
    seimeiouin = Fellowship.create!(name: "聖明王院", color_code: "#222222", region: @region)
    daibutsuden = Fellowship.create!(name: "大仏殿", color_code: "#333333", region: @region)
    ibaraki = Fellowship.create!(name: "茨城", color_code: "#444444", region: @region)
    CeremonySchedule.create!(
      event: @event, fellowship: seimeiouin, ceremony_at: Time.zone.local(2026, 10, 2, 10),
      place: "聖明王院", assistant_count: 1, spirit_count: 30
    )
    CeremonyScheduleAllocation.create!(event: @event, fellowship: @meeting, spirit_count: 12)
    CeremonyScheduleAllocation.create!(event: @event, fellowship: seimeiouin, spirit_count: 38)

    result = CeremonyScheduleAllocation.rebalance_for_qualified_count!(event: @event, qualified_spirit_count: 100)

    assert result[:rebalanced]
    assert_equal 50, CeremonyScheduleAllocation.find_by!(event: @event, fellowship: @meeting).spirit_count
    assert_equal 0, CeremonyScheduleAllocation.find_by!(event: @event, fellowship: seimeiouin).spirit_count
    assert_equal 0, CeremonyScheduleAllocation.find_by!(event: @event, fellowship: daibutsuden).spirit_count
    assert_equal 50, CeremonyScheduleAllocation.find_by!(event: @event, fellowship: ibaraki).spirit_count
    assert_equal 100, CeremonyScheduleAllocation.allocated_spirit_count_for(@event)
  end
end
