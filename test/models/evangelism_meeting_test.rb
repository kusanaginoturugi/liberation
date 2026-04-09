require "test_helper"

class EvangelismMeetingTest < ActiveSupport::TestCase
  test "active scope returns only active meetings in display order" do
    region = Region.create!(name: "共通")
    inactive = EvangelismMeeting.create!(name: "旧伝道会", color_code: "#111111", display_order: 30, active: false, region:)
    late = EvangelismMeeting.create!(name: "B会場", color_code: "#222222", display_order: 20, active: true, region:)
    early = EvangelismMeeting.create!(name: "A会場", color_code: "#333333", display_order: 10, active: true, region:)

    assert_equal [early, late], EvangelismMeeting.active.display_sorted.to_a
    assert_not_includes EvangelismMeeting.active.display_sorted, inactive
  end
end
