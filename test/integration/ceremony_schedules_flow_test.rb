require "test_helper"

class CeremonySchedulesFlowTest < ActionDispatch::IntegrationTest
  setup do
    @region = Region.create!(name: "共通")
    @event = Event.create!(name: "第75次超抜式")
    @previous_event = Event.create!(name: "第74次超抜式", closed: true)
    @meeting = Fellowship.create!(name: "大江戸", color_code: "#C8C4C1", display_order: 2, region: @region)
    @other_meeting = Fellowship.create!(name: "札幌会場", color_code: "#111111", display_order: 1, region: @region)
    @user = User.create!(
      name: "担当者",
      email: "member@example.com",
      password: "password123",
      password_confirmation: "password123",
      region: @region,
      fellowship: @meeting
    )
    @other_user = User.create!(
      name: "別担当者",
      email: "other@example.com",
      password: "password123",
      password_confirmation: "password123",
      region: @region,
      fellowship: @other_meeting
    )
  end

  test "public can view schedules ordered by ceremony date with spirit total" do
    EventDetail.create!(event: @event, region: @region, total_serial_count: 1_650)
    newer_schedule = CeremonySchedule.create!(
      fellowship: @meeting,
      event: @event,
      ceremony_at: Time.zone.local(2026, 5, 2, 14, 0),
      place: "大江戸会館",
      assistant_count: 2,
      spirit_count: 20,
      minister_name: "山田点伝師"
    )
    older_schedule = CeremonySchedule.create!(
      fellowship: @other_meeting,
      event: @event,
      ceremony_at: Time.zone.local(2026, 5, 1, 10, 30),
      place: "札幌会館",
      assistant_count: 1,
      spirit_count: 15,
      minister_name: "佐藤点伝師"
    )

    get ceremony_schedules_path

    assert_response :success
    assert_includes response.body, "挙行予定表"
    assert_includes response.body, "第75次超抜式"
    assert_includes response.body, "第74次超抜式"
    assert_includes response.body, "修霊番号一覧"
    assert_includes response.body, older_schedule.place
    assert_includes response.body, newer_schedule.place
    assert_operator response.body.index(older_schedule.place), :<, response.body.index(newer_schedule.place)
    assert_includes response.body, "霊数合計"
    assert_includes response.body, ">35<"
    assert_includes response.body, "合格霊数"
    assert_includes response.body, ">1,650<"
    assert_includes response.body, "schedule-row-even"
    assert_includes response.body, "schedule-row-odd"
    assert_not_includes response.body, "予定追加"
    assert_not_includes response.body, "編集"
  end

  test "number allocations follow the first scheduled date for each fellowship" do
    CeremonySchedule.create!(
      fellowship: @other_meeting,
      event: @event,
      ceremony_at: Time.zone.local(2026, 5, 1, 10, 30),
      place: "札幌会館",
      assistant_count: 1,
      spirit_count: 15
    )
    CeremonySchedule.create!(
      fellowship: @meeting,
      event: @event,
      ceremony_at: Time.zone.local(2026, 5, 2, 10, 30),
      place: "大江戸会館",
      assistant_count: 1,
      spirit_count: 20
    )
    CeremonySchedule.create!(
      fellowship: @other_meeting,
      event: @event,
      ceremony_at: Time.zone.local(2026, 5, 3, 10, 30),
      place: "札幌会館",
      assistant_count: 1,
      spirit_count: 5
    )

    get ceremony_schedules_path

    assert_response :success
    assert_includes response.body, "番号割り振り"
    allocation_section = response.body.split("番号割り振り", 2).last
    assert_operator allocation_section.index("札幌会場"), :<, allocation_section.index("大江戸")
    assert_includes allocation_section, "1 〜 20"
    assert_includes allocation_section, "21 〜 40"

    @meeting.update!(name: "大江戸")
    @other_meeting.update!(name: "山梨")
    get ceremony_schedules_path, params: { allocation_sort: :fellowship, allocation_direction: :asc }

    allocation_section = response.body.split("番号割り振り", 2).last
    assert_operator allocation_section.index("大江戸"), :<, allocation_section.index("山梨")

    get ceremony_schedules_path, params: { allocation_sort: :fellowship, allocation_direction: :desc }

    allocation_section = response.body.split("番号割り振り", 2).last
    assert_operator allocation_section.index("山梨"), :<, allocation_section.index("大江戸")
    assert_includes allocation_section, "event_id=#{@event.id}\""
    assert_not_includes allocation_section, "allocation_sort=fellowship"

    get ceremony_schedules_path

    allocation_section = response.body.split("番号割り振り", 2).last
    assert_operator allocation_section.index("山梨"), :<, allocation_section.index("大江戸")
  end

  test "schedule page reports when Cloudflare PDF is not configured" do
    CeremonySchedule.create!(
      fellowship: @meeting,
      event: @event,
      ceremony_at: Time.zone.local(2026, 5, 2, 10, 30),
      place: "大江戸会館",
      assistant_count: 2,
      spirit_count: 20,
      minister_name: "山田点伝師"
    )

    get export_ceremony_schedules_path(event_id: @event.id)

    assert_response :service_unavailable
    assert_includes response.body, "Cloudflare PDFの設定がありません"
  end

  test "assigned user can create and edit own meeting schedule" do
    post session_path, params: { login_id: @user.login_id, password: "password123" }

    assert_difference("CeremonySchedule.count", 1) do
      post ceremony_schedules_path, params: {
        event_id: @event.id,
        ceremony_schedule: {
          fellowship_id: @other_meeting.id,
          ceremony_at: "2026-05-03T09:00",
          place: "大江戸会館",
          assistant_count: 3,
          spirit_count: 25,
          minister_name: ""
        }
      }
    end

    schedule = CeremonySchedule.order(:id).last
    assert_redirected_to ceremony_schedules_path(event_id: @event.id)
    assert_equal @meeting, schedule.fellowship
    assert_equal @event, schedule.event

    patch ceremony_schedule_path(schedule), params: {
      ceremony_schedule: {
        ceremony_at: "2026-05-03T11:00",
        place: "大江戸新会館",
        assistant_count: 4,
        spirit_count: 28,
        minister_name: "田中点伝師"
      }
    }

    assert_redirected_to ceremony_schedules_path(event_id: @event.id)
    schedule.reload
    assert_equal "大江戸新会館", schedule.place
    assert_equal 28, schedule.spirit_count
  end

  test "assigned user cannot edit other meeting schedule" do
    schedule = CeremonySchedule.create!(
      fellowship: @other_meeting,
      event: @event,
      ceremony_at: Time.zone.local(2026, 5, 1, 10, 30),
      place: "札幌会館",
      assistant_count: 1,
      spirit_count: 15,
      minister_name: "佐藤点伝師"
    )

    post session_path, params: { login_id: @user.login_id, password: "password123" }
    get edit_ceremony_schedule_path(schedule)

    assert_redirected_to ceremony_schedules_path
  end

  test "assigned user can delete own meeting schedule but not another meeting schedule" do
    own_schedule = CeremonySchedule.create!(
      fellowship: @meeting,
      event: @event,
      ceremony_at: Time.zone.local(2026, 5, 1, 10, 30),
      place: "大江戸会館",
      assistant_count: 1,
      spirit_count: 15
    )
    other_schedule = CeremonySchedule.create!(
      fellowship: @other_meeting,
      event: @event,
      ceremony_at: Time.zone.local(2026, 5, 2, 10, 30),
      place: "札幌会館",
      assistant_count: 1,
      spirit_count: 15
    )

    post session_path, params: { login_id: @user.login_id, password: "password123" }

    assert_difference("CeremonySchedule.count", -1) do
      delete ceremony_schedule_path(own_schedule)
    end
    assert_redirected_to ceremony_schedules_path(event_id: @event.id)

    assert_no_difference("CeremonySchedule.count") do
      delete ceremony_schedule_path(other_schedule)
    end
    assert_redirected_to ceremony_schedules_path
  end

  test "schedules are shown only for the selected event" do
    current_schedule = CeremonySchedule.create!(
      fellowship: @meeting,
      event: @event,
      ceremony_at: Time.zone.local(2026, 5, 1, 10, 30),
      place: "第75次会場",
      assistant_count: 1,
      spirit_count: 15
    )
    previous_schedule = CeremonySchedule.create!(
      fellowship: @meeting,
      event: @previous_event,
      ceremony_at: Time.zone.local(2026, 5, 2, 10, 30),
      place: "第74次会場",
      assistant_count: 1,
      spirit_count: 15
    )

    get ceremony_schedules_path(event_id: @event.id)

    assert_includes response.body, current_schedule.place
    assert_not_includes response.body, previous_schedule.place
  end

  test "admin can assign user meeting" do
    admin = User.create!(
      name: "管理者",
      email: "admin@example.com",
      password: "password123",
      password_confirmation: "password123",
      region: @region,
      admin: true
    )

    post session_path, params: { login_id: admin.login_id, password: "password123" }
    patch user_path(@other_user), params: {
      user: {
        login_id: @other_user.login_id,
        name: @other_user.name,
        email: @other_user.email,
        region_id: @region.id,
        fellowship_id: @meeting.id,
        password: "",
        password_confirmation: ""
      }
    }

    assert_redirected_to users_path
    assert_equal @meeting, @other_user.reload.fellowship
  end
end
