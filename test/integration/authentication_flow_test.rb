require "test_helper"

class AuthenticationFlowTest < ActionDispatch::IntegrationTest
  setup do
    @region = Region.create!(name: "共通")
    @event = Event.create!(name: "第1回超抜式")
    EventDetail.create!(event: @event, region: @region, total_serial_count: 1667)
    @user = User.create!(
      name: "管理者",
      email: "admin@example.com",
      password: "password123",
      password_confirmation: "password123",
      region: @region
    )
    EvangelismMeeting.create!(name: "大江戸", color_code: "#C8C4C1", region: @region)
    SystemSetting.create!(key: SystemSetting::TOTAL_SERIAL_COUNT_KEY, value: "1667")
  end

  test "unauthenticated users can view root page" do
    get root_path

    assert_response :success
    assert_includes response.body, "修霊番号一覧"
    assert_includes response.body, "第1回超抜式"
    assert_includes response.body, "ログイン"
    assert_not_includes response.body, "聖院"
    assert_not_includes response.body, "修霊番号登録"
  end

  test "user can sign in and access root page" do
    post session_path, params: { email: @user.email, password: "password123" }

    assert_redirected_to root_path
    follow_redirect!
    assert_response :success
    assert_includes response.body, "修霊番号一覧"
    assert_includes response.body, "修霊番号登録"
    assert_includes response.body, "ログアウト"
    assert_includes response.body, "大江戸"
  end
end
