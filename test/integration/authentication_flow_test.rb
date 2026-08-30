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
    Fellowship.create!(name: "大江戸", color_code: "#C8C4C1", region: @region, enabled: true)
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

  test "Authentik管理者はメールアドレスで既存ユーザーと結び付きます" do
    with_authentik do
      claims = {
        "sub" => "authentik-admin-1",
        "email" => @user.email,
        "name" => "Authentik管理者",
        "groups" => [ "liberation-admin" ]
      }

      complete_authentik_login(claims)

      assert_redirected_to root_path
      @user.reload
      assert_equal "authentik-admin-1", @user.authentik_subject
      assert @user.admin?
      assert_equal "Authentik管理者", @user.name
    end
  end

  test "Authentikの伝道会グループで新しい担当者を作成します" do
    with_authentik do
      claims = {
        "sub" => "authentik-oedo-1",
        "email" => "oedo@example.com",
        "name" => "大江戸担当者",
        "groups" => [ "liberation-oedo" ]
      }

      complete_authentik_login(claims)

      user = User.find_by!(email: "oedo@example.com")
      assert_equal "authentik-oedo-1", user.authentik_subject
      assert_equal "大江戸", user.fellowship.name
      assert_not user.admin?
    end
  end

  test "既存のmyouou管理者グループもAuthentik管理者として扱います" do
    with_authentik do
      claims = {
        "sub" => "authentik-myouou-admin-1",
        "email" => "myouou-admin@example.com",
        "name" => "既存管理者",
        "groups" => [ "myouou-admins", "大江戸", "お台場" ]
      }

      complete_authentik_login(claims)

      assert User.find_by!(email: "myouou-admin@example.com").admin?
    end
  end

  test "Authentikで権限が設定されていない利用者はログインできません" do
    with_authentik do
      claims = {
        "sub" => "authentik-unassigned-1",
        "email" => "unassigned@example.com",
        "name" => "未設定者",
        "groups" => []
      }

      complete_authentik_login(claims)

      assert_redirected_to new_session_path
      follow_redirect!
      assert_includes response.body, "管理者または担当伝道会が設定されていません"
      assert_nil User.find_by(email: "unassigned@example.com")
    end
  end

  private

  def with_authentik
    previous_secret = ENV["AUTHENTIK_CLIENT_SECRET"]
    ENV["AUTHENTIK_CLIENT_SECRET"] = "test-secret"
    yield
  ensure
    ENV["AUTHENTIK_CLIENT_SECRET"] = previous_secret
  end

  def complete_authentik_login(claims)
    original_exchange_code = AuthentikClient.method(:exchange_code)
    original_userinfo = AuthentikClient.method(:userinfo)
    AuthentikClient.define_singleton_method(:exchange_code) { |_| "test-access-token" }
    AuthentikClient.define_singleton_method(:userinfo) { |_| claims }

    get authentik_login_path
    state = Rack::Utils.parse_query(URI.parse(response.location).query).fetch("state")
    get authentik_callback_path, params: { code: "test-code", state: state }
  ensure
    AuthentikClient.define_singleton_method(:exchange_code, original_exchange_code) if original_exchange_code
    AuthentikClient.define_singleton_method(:userinfo, original_userinfo) if original_userinfo
  end
end
