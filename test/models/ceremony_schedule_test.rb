require "test_helper"

class CeremonyScheduleTest < ActiveSupport::TestCase
  setup do
    region = Region.create!(name: "共通")
    @meeting = Fellowship.create!(name: "大江戸", color_code: "#C8C4C1", region:)
  end

  test "validates required fields and nonnegative counts" do
    schedule = CeremonySchedule.new(fellowship: @meeting, assistant_count: -1, spirit_count: -1)

    assert_not schedule.valid?
    assert_includes schedule.errors[:ceremony_at], "can't be blank"
    assert_includes schedule.errors[:place], "can't be blank"
    assert schedule.errors[:assistant_count].any?
    assert schedule.errors[:spirit_count].any?
  end

  test "allows the minister name to be blank" do
    schedule = CeremonySchedule.new(
      fellowship: @meeting,
      ceremony_at: Time.zone.local(2026, 8, 30, 10, 0),
      place: "大江戸会館",
      assistant_count: 1,
      spirit_count: 10
    )

    assert_predicate schedule, :valid?
  end
end
