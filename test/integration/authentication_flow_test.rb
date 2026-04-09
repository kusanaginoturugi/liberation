require "test_helper"

class AuthenticationFlowTest < ActionDispatch::IntegrationTest
  setup do
    @region = Region.create!(name: "共通")
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

  test "redirects unauthenticated users to sign in" do
    get root_path

    assert_redirected_to new_session_path
  end

  test "user can sign in and access root page" do
    post session_path, params: { email: @user.email, password: "password123" }

    assert_redirected_to root_path
    follow_redirect!
    assert_response :success
    assert_includes response.body, "超抜報告"
    assert_includes response.body, "ログアウト"
    assert_includes response.body, "大江戸"
  end
end
