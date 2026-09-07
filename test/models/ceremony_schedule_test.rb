require "test_helper"

class CeremonyScheduleTest < ActiveSupport::TestCase
  setup do
    region = Region.create!(name: "共通")
    @meeting = Fellowship.create!(name: "大江戸", color_code: "#C8C4C1", region:)
    @event = Event.create!(name: "第75回超抜式")
  end

  test "validates required fields and nonnegative counts" do
    schedule = CeremonySchedule.new(event: @event, fellowship: @meeting, assistant_count: -1, spirit_count: -1)

    assert_not schedule.valid?
    assert_includes schedule.errors[:ceremony_at], "can't be blank"
    assert_includes schedule.errors[:place], "can't be blank"
    assert schedule.errors[:assistant_count].any?
    assert schedule.errors[:spirit_count].any?
  end

  test "allows the minister name to be blank" do
    schedule = CeremonySchedule.new(
      fellowship: @meeting,
      event: @event,
      ceremony_at: Time.zone.local(2026, 8, 30, 10, 0),
      place: "大江戸会館",
      assistant_count: 1,
      spirit_count: 10
    )

    assert_predicate schedule, :valid?
    assert_predicate schedule, :save
  end

  test "allows one special schedule without a fellowship or counts" do
    schedule = CeremonySchedule.new(
      event: @event,
      special_schedule: true,
      ceremony_at: Time.zone.local(2026, 10, 18, 10, 0),
      place: "聖泉珠院"
    )

    assert_predicate schedule, :valid?
    assert_predicate schedule, :save
    assert_equal "聖泉珠院・海外", schedule.display_name

    duplicate = CeremonySchedule.new(
      event: @event,
      special_schedule: true,
      ceremony_at: Time.zone.local(2026, 10, 18, 11, 0),
      place: "海外"
    )

    assert_not_predicate duplicate, :valid?
    assert duplicate.errors[:event_id].any?
  end

  test "calculates the special schedule total from its number range" do
    schedule = CeremonySchedule.new(
      event: @event,
      special_schedule: true,
      ceremony_at: Time.zone.local(2026, 10, 18, 10, 0),
      place: "聖泉珠院",
      serial_number_from: 201,
      serial_number_to: 250
    )

    assert_predicate schedule, :valid?
    assert_equal 50, schedule.special_spirit_total
    assert_equal 50, schedule.spirit_count
  end
end
