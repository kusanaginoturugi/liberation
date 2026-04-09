require "test_helper"

class AdminManagementFlowTest < ActionDispatch::IntegrationTest
  setup do
    @region = Region.create!(name: "共通")
    @other_region = Region.create!(name: "札幌")
    @event = Event.create!(name: "第1回超抜式")
    @meeting = EvangelismMeeting.create!(name: "大江戸", color_code: "#C8C4C1", region: @region)
    @admin = User.create!(
      name: "管理者",
      email: "admin@example.com",
      password: "password123",
      password_confirmation: "password123",
      region: @region,
      admin: true
    )
    @user = User.create!(
      name: "一般",
      email: "user@example.com",
      password: "password123",
      password_confirmation: "password123",
      region: @region,
      admin: false
    )
    SystemSetting.create!(key: SystemSetting::TOTAL_SERIAL_COUNT_KEY, value: "1667")
  end

  test "admin sees only meeting management link in single region mode" do
    post session_path, params: { email: @admin.email, password: "password123" }

    get root_path
    assert_includes response.body, "修霊番号一覧"
    assert_not_includes response.body, "聖院一覧"
    assert_includes response.body, "超抜式一覧"
    assert_includes response.body, "伝道会一覧"
  end

  test "admin can update event" do
    post session_path, params: { email: @admin.email, password: "password123" }

    get events_path
    assert_includes response.body, @event.name
    assert_includes response.body, edit_event_path(@event)

    patch event_path(@event), params: {
      event: {
        name: "第1回春期超抜式"
      }
    }

    assert_redirected_to events_path
    assert_equal "第1回春期超抜式", @event.reload.name
  end

  test "admin can still update region directly" do
    post session_path, params: { email: @admin.email, password: "password123" }

    get regions_path
    assert_includes response.body, "登録伝道会数"
    assert_includes response.body, "1"
    assert_includes response.body, edit_region_path(@region)

    patch region_path(@region), params: { region: { name: "本部" } }

    assert_redirected_to regions_path
    assert_equal "本部", @region.reload.name
  end

  test "admin can update evangelism meeting" do
    post session_path, params: { email: @admin.email, password: "password123" }

    get evangelism_meetings_path
    assert_not_includes response.body, ">編集<"
    assert_includes response.body, edit_evangelism_meeting_path(@meeting)

    get edit_evangelism_meeting_path(@meeting)
    assert_includes response.body, "type=\"color\""

    patch evangelism_meeting_path(@meeting), params: {
      evangelism_meeting: {
        name: "新大江戸",
        color_code: "#123456",
        region_id: @other_region.id,
        display_order: 99,
        active: "0"
      }
    }

    assert_redirected_to evangelism_meetings_path
    @meeting.reload
    assert_equal "新大江戸", @meeting.name
    assert_equal "#123456", @meeting.color_code
    assert_equal @other_region.id, @meeting.region_id
    assert_equal 99, @meeting.display_order
    assert_not @meeting.active?
  end

  test "non admin cannot access management pages" do
    post session_path, params: { email: @user.email, password: "password123" }

    get regions_path
    assert_redirected_to root_path

    get evangelism_meetings_path
    assert_redirected_to root_path

    get events_path
    assert_redirected_to root_path
  end
end
