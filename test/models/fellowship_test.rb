require "test_helper"

class FellowshipTest < ActiveSupport::TestCase
  test "active scope returns only active meetings in display order" do
    region = Region.create!(name: "共通")
    inactive = Fellowship.create!(name: "旧伝道会", color_code: "#111111", display_order: 30, active: false, region:)
    late = Fellowship.create!(name: "B会場", color_code: "#222222", display_order: 20, active: true, region:)
    early = Fellowship.create!(name: "A会場", color_code: "#333333", display_order: 10, active: true, region:)

    assert_equal [ early, late ], Fellowship.active.display_sorted.to_a
    assert_not_includes Fellowship.active.display_sorted, inactive
  end
end
