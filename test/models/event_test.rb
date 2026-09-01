require "test_helper"

class EventTest < ActiveSupport::TestCase
  test "does not allow a chobatsu period ending before it starts" do
    event = Event.new(
      name: "第75次超抜式",
      chobatsu_starts_on: Date.new(2026, 12, 1),
      chobatsu_ends_on: Date.new(2026, 10, 18)
    )

    assert_not event.valid?
    assert_includes event.errors[:chobatsu_ends_on], "は開始日以降にしてください"
  end
end
