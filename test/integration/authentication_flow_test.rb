require "test_helper"

class AuthenticationFlowTest < ActionDispatch::IntegrationTest
  setup do
    @region = Region.create!(name: "共通")
    @event = Event.create!(name: "第1回超抜式")
    EventDetail.create!(event: @event, region: @region, total_serial_count: 1667)
    @user = User.create!(
      name: "管理者",
      login_id: "1",
      email: "admin@example.com",
      password: "password123",
      password_confirmation: "password123",
      region: @region
    )
    EvangelismMeeting.create!(name: "大江戸", color_code: "#C8C4C1", region: @region)
  end

  test "unauthenticated users can view root page" do
    get root_path

    assert_response :success
    assert_includes response.body, "修霊番号一覧"
    assert_includes response.body, "第1回超抜式"
    assert_includes response.body, "対象聖院"
    assert_includes response.body, "ログイン"
    assert_not_includes response.body, "挙行報告"
  end

  test "root page still shows event selector when event detail is missing" do
    EventDetail.delete_all

    get root_path

    assert_response :success
    assert_includes response.body, 'name="event_id"'
    assert_includes response.body, @event.name
  end

  test "user can sign in and access root page" do
    post session_path, params: { login_id: " １ ", password: "password123", remember_me: "1" }

    assert_redirected_to root_path
    assert cookies[:remember_user_id].present?
    follow_redirect!
    assert_response :success
    assert_includes response.body, "修霊番号一覧"
    assert_includes response.body, "挙行報告"
    assert_includes response.body, "ログアウト"
    assert_includes response.body, "大江戸"
  end

  test "login page advertises normalized login id input and remember me" do
    get new_session_path

    assert_response :success
    assert_includes response.body, 'autocomplete="username"'
    assert_includes response.body, 'autocapitalize="none"'
    assert_includes response.body, 'data-login-id-normalize="true"'
    assert_includes response.body, "ログイン状態"
    assert_includes response.body, "保持する"
    assert_includes response.body, "今回のみ"
  end

  test "remember me cookie restores login after session cookie is cleared" do
    post session_path, params: { login_id: @user.login_id, password: "password123", remember_me: "1" }

    assert_redirected_to root_path
    cookies.delete(Rails.application.config.session_options[:key])

    get root_path

    assert_response :success
    assert_includes response.body, "挙行報告"
    assert_includes response.body, "ログアウト"
  end

  test "sign in without remember me does not set remember cookie" do
    post session_path, params: { login_id: @user.login_id, password: "password123", remember_me: "0" }

    assert_redirected_to root_path
    assert_nil cookies[:remember_user_id]
  end

  test "sign in shows detailed message when fields are blank" do
    post session_path, params: { login_id: "", password: "" }

    assert_response :unprocessable_content
    assert_includes response.body, "ログインIDとパスワードを入力してください"
  end

  test "sign in failure explains login id normalization" do
    post session_path, params: { login_id: " １ ", password: "wrong-password" }

    assert_response :unprocessable_content
    assert_includes response.body, "ログインIDの全角文字や空白は自動で補正しています"
  end
end
