require "test_helper"

class AdminManagementFlowTest < ActionDispatch::IntegrationTest
  setup do
    @region = Region.create!(name: "共通")
    @other_region = Region.create!(name: "札幌")
    @event = Event.create!(name: "第1回超抜式")
    @event_detail = EventDetail.create!(event: @event, region: @region, total_serial_count: 1667)
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
  end

  test "admin sees only meeting management link in single region mode" do
    post session_path, params: { login_id: @admin.login_id, password: "password123" }

    get root_path
    assert_includes response.body, "修霊番号一覧"
    assert_not_includes response.body, "聖院一覧"
    assert_includes response.body, "設定"
    assert_includes response.body, "ユーザー一覧"
    assert_includes response.body, "超抜式一覧"
    assert_includes response.body, "伝道会一覧"
  end

  test "admin can update settings" do
    post session_path, params: { login_id: @admin.login_id, password: "password123" }

    get edit_settings_path
    assert_response :success
    assert_includes response.body, "配色のグラデーションを有効にする"
    assert_includes response.body, "数字にドロップシャドウを付ける"

    patch settings_path, params: {
      settings: {
        gradient_enabled: "false",
        number_shadow_enabled: "true"
      }
    }

    assert_redirected_to edit_settings_path
    assert_not SystemSetting.gradient_enabled?
    assert SystemSetting.number_shadow_enabled?
  end

  test "admin can create user" do
    post session_path, params: { login_id: @admin.login_id, password: "password123" }

    get users_path
    assert_includes response.body, "ユーザー追加"

    assert_difference("User.count", 1) do
      post users_path, params: {
        user: {
          name: "追加ユーザー",
          email: "added@example.com",
          region_id: @region.id,
          password: "password123",
          password_confirmation: "password123",
          admin: "0"
        }
      }
    end

    assert_redirected_to users_path
    assert_equal "追加ユーザー", User.find_by!(email: "added@example.com").name
  end

  test "admin can update own profile without changing password" do
    post session_path, params: { login_id: @admin.login_id, password: "password123" }

    get edit_user_path(@admin)
    assert_response :success
    assert_includes response.body, "プロフィール編集"

    patch user_path(@admin), params: {
      user: {
        name: "管理者更新",
        email: "admin-updated@example.com",
        region_id: @other_region.id,
        password: "",
        password_confirmation: ""
      }
    }

    assert_redirected_to root_path
    @admin.reload
    assert_equal "管理者更新", @admin.name
    assert_equal "admin-updated@example.com", @admin.email
    assert_equal @other_region.id, @admin.region_id
    assert @admin.authenticate("password123")
  end

  test "admin can update another user and admin role" do
    post session_path, params: { login_id: @admin.login_id, password: "password123" }

    get edit_user_path(@user)
    assert_response :success
    assert_includes response.body, "ユーザー編集"

    patch user_path(@user), params: {
      user: {
        name: "一般更新",
        email: "user-updated@example.com",
        region_id: @other_region.id,
        admin: "1",
        password: "",
        password_confirmation: ""
      }
    }

    assert_redirected_to users_path
    @user.reload
    assert_equal "一般更新", @user.name
    assert_equal "user-updated@example.com", @user.email
    assert_equal @other_region.id, @user.region_id
    assert @user.admin?
    assert @user.authenticate("password123")
  end

  test "admin can update event" do
    post session_path, params: { login_id: @admin.login_id, password: "password123" }

    other_event = Event.create!(name: "別超抜式", closed: true)
    EventDetail.create!(event: other_event, region: @region, total_serial_count: 1667)

    get events_path
    assert_includes response.body, @event.name
    assert_includes response.body, edit_event_path(@event)

    get edit_event_path(@event)
    assert_includes response.body, 'name="event[total_serial_count]"'

    patch event_path(@event), params: {
      event: {
        name: "第1回春期超抜式",
        total_serial_count: 1800
      }
    }

    assert_redirected_to events_path
    assert_equal "第1回春期超抜式", @event.reload.name
    assert_equal 1800, @event.event_details.find_by!(region_id: @region.id).total_serial_count
    assert_not @event.closed?
    assert other_event.reload.closed?
  end

  test "admin can delete event without reports" do
    post session_path, params: { login_id: @admin.login_id, password: "password123" }

    deletable_event = Event.create!(name: "削除対象")
    EventDetail.create!(event: deletable_event, region: @region, total_serial_count: 1667)

    assert_difference("Event.count", -1) do
      delete event_path(deletable_event)
    end

    assert_redirected_to events_path
    assert_nil Event.find_by(id: deletable_event.id)
  end

  test "admin cannot delete event with reports" do
    post session_path, params: { login_id: @admin.login_id, password: "password123" }

    ChobatsuReport.create!(
      ceremony_date: Date.current,
      region: @region,
      event: @event,
      user: @admin,
      evangelism_meeting: @meeting,
      participant_count: 1,
      serial_number_from: 1,
      serial_number_to: 1,
      merit_fee_total: 5000
    )

    get edit_event_path(@event)
    assert_includes response.body, "削除できません"
    assert_includes response.body, "超抜報告が紐づいている超抜式は削除できません"

    assert_no_difference("Event.count") do
      delete event_path(@event)
    end

    assert_redirected_to edit_event_path(@event)
  end

  test "admin can create event with event details" do
    post session_path, params: { login_id: @admin.login_id, password: "password123" }

    assert_difference("Event.count", 1) do
      post events_path, params: {
        event: {
          name: "第2回超抜式",
          total_serial_count: 1777
        }
      }
    end

    event = Event.find_by!(name: "第2回超抜式")
    assert_redirected_to events_path
    assert_equal [ @region.id, @other_region.id ].sort, event.event_details.pluck(:region_id).sort
    assert_equal 1777, event.event_details.find_by!(region_id: @region.id).total_serial_count
    assert_equal 1667, event.event_details.find_by!(region_id: @other_region.id).total_serial_count
    assert_not event.closed?
    assert @event.reload.closed?
  end

  test "admin can update event detail" do
    post session_path, params: { login_id: @admin.login_id, password: "password123" }

    get event_event_details_path(@event)
    assert_includes response.body, @region.name
    assert_includes response.body, edit_event_event_detail_path(@event, @event_detail)

    patch event_event_detail_path(@event, @event_detail), params: {
      event_detail: {
        total_serial_count: 1800
      }
    }

    assert_redirected_to event_event_details_path(@event)
    assert_equal 1800, @event_detail.reload.total_serial_count
  end

  test "event detail index recreates missing region settings" do
    post session_path, params: { login_id: @admin.login_id, password: "password123" }

    EventDetail.delete_all

    get event_event_details_path(@event)

    assert_response :success
    assert_includes response.body, @region.name
    assert_includes response.body, @other_region.name
    assert_equal [ @region.id, @other_region.id ].sort, @event.event_details.reload.pluck(:region_id).sort
  end

  test "numeric inputs advertise numeric-only hints" do
    post session_path, params: { login_id: @admin.login_id, password: "password123" }

    get new_chobatsu_report_path
    assert_response :success
    assert_includes response.body, 'name="chobatsu_report[participant_count]"'
    assert_includes response.body, 'inputmode="numeric"'
    assert_includes response.body, 'pattern="[0-9]*"'
    assert_includes response.body, 'data-numeric-only="true"'

    get edit_event_event_detail_path(@event, @event_detail)
    assert_response :success
    assert_includes response.body, 'name="event_detail[total_serial_count]"'
    assert_includes response.body, 'data-numeric-only="true"'

    get new_evangelism_meeting_path
    assert_response :success
    assert_includes response.body, 'name="evangelism_meeting[display_order]"'
    assert_includes response.body, 'data-numeric-only="true"'
  end

  test "admin can still update region directly" do
    post session_path, params: { login_id: @admin.login_id, password: "password123" }

    get regions_path
    assert_includes response.body, "登録伝道会数"
    assert_includes response.body, "1"
    assert_includes response.body, edit_region_path(@region)

    patch region_path(@region), params: { region: { name: "本部" } }

    assert_redirected_to regions_path
    assert_equal "本部", @region.reload.name
  end

  test "admin can update evangelism meeting" do
    post session_path, params: { login_id: @admin.login_id, password: "password123" }

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

  test "admin can create evangelism meeting" do
    post session_path, params: { login_id: @admin.login_id, password: "password123" }

    assert_difference("EvangelismMeeting.count", 1) do
      post evangelism_meetings_path, params: {
        evangelism_meeting: {
          name: "新会場",
          color_code: "#654321",
          region_id: @region.id,
          display_order: 55,
          active: "1"
        }
      }
    end

    assert_redirected_to evangelism_meetings_path
    assert_equal "新会場", EvangelismMeeting.find_by!(name: "新会場").name
  end

  test "non admin cannot access management pages" do
    post session_path, params: { login_id: @user.login_id, password: "password123" }

    get regions_path
    assert_redirected_to root_path

    get evangelism_meetings_path
    assert_redirected_to root_path

    get events_path
    assert_redirected_to root_path

    get event_event_details_path(@event)
    assert_redirected_to root_path

    get users_path
    assert_redirected_to root_path

    get new_user_path
    assert_redirected_to root_path

    get edit_settings_path
    assert_redirected_to root_path
  end

  test "non admin can update own profile but cannot edit another user" do
    post session_path, params: { login_id: @user.login_id, password: "password123" }

    get edit_user_path(@user)
    assert_response :success
    assert_includes response.body, "プロフィール編集"

    patch user_path(@user), params: {
      user: {
        name: "一般更新",
        email: "user-updated@example.com",
        password: "",
        password_confirmation: ""
      }
    }

    assert_redirected_to root_path
    @user.reload
    assert_equal "一般更新", @user.name
    assert_equal "user-updated@example.com", @user.email
    assert_equal @region.id, @user.region_id
    assert @user.authenticate("password123")

    get edit_user_path(@admin)
    assert_redirected_to root_path

    patch user_path(@admin), params: {
      user: {
        name: "不正更新",
        email: "hijack@example.com"
      }
    }

    assert_redirected_to root_path
    @admin.reload
    assert_equal "管理者", @admin.name
    assert_equal "admin@example.com", @admin.email
  end
end
