require "test_helper"

class CeremonySchedulesFlowTest < ActionDispatch::IntegrationTest
  setup do
    @region = Region.create!(name: "共通")
    @event = Event.create!(name: "第75次修霊超抜式")
    @previous_event = Event.create!(name: "第74次修霊超抜式", closed: true)
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
    @event.update!(
      judgment_ceremony_on: Date.new(2026, 10, 18),
      chobatsu_starts_on: Date.new(2026, 10, 18),
      chobatsu_ends_on: Date.new(2026, 12, 1)
    )
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
    assert_includes response.body, "/icon.svg?v=20260831"
    assert_includes response.body, "第75次修霊超抜式"
    assert_includes response.body, "第74次修霊超抜式"
    assert_includes response.body, "修霊超度審判式"
    assert_includes response.body, "10月18日"
    assert_includes response.body, "超抜期間"
    assert_includes response.body, "10月18日〜12月1日"
    assert_includes response.body, "修霊番号一覧"
    assert_includes response.body, older_schedule.place
    assert_includes response.body, newer_schedule.place
    assert_operator response.body.index(older_schedule.place), :<, response.body.index(newer_schedule.place)
    assert_includes response.body, "霊数合計"
    assert_includes response.body, ">35<"
    assert_includes response.body, "合格霊数"
    assert_includes response.body, ">1,650<"
    assert_includes response.body, "3壇"
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
    assert_includes allocation_section, "allocation-row-even"
    assert_includes allocation_section, "allocation-row-odd"

    @meeting.update!(name: "大江戸")
    @other_meeting.update!(name: "山梨")

    get ceremony_schedules_path, params: { schedule_sort: :fellowship, schedule_direction: :asc }

    schedule_section = response.body.split("番号割り振り", 2).first
    assert_operator schedule_section.index("大江戸"), :<, schedule_section.index("山梨")
    allocation_section = response.body.split("番号割り振り", 2).last
    assert_operator allocation_section.index("山梨"), :<, allocation_section.index("大江戸")

    get ceremony_schedules_path, params: { schedule_sort: :fellowship, schedule_direction: :desc }

    schedule_section = response.body.split("番号割り振り", 2).first
    assert_operator schedule_section.index("山梨"), :<, schedule_section.index("大江戸")

    get ceremony_schedules_path

    schedule_section = response.body.split("番号割り振り", 2).first
    assert_operator schedule_section.index("山梨"), :<, schedule_section.index("大江戸")

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

  test "admin can create a joint schedule with spirit counts for each fellowship" do
    saitama = Fellowship.create!(name: "埼玉", color_code: "#123456", region: @region)
    yamanashi = Fellowship.create!(name: "山梨", color_code: "#654321", region: @region)
    admin = User.create!(
      name: "管理者", email: "admin-joint@example.com", password: "password123", password_confirmation: "password123",
      region: @region, admin: true
    )

    post session_path, params: { login_id: admin.login_id, password: "password123" }
    get new_ceremony_schedule_path(event_id: @event.id)

    assert_response :success
    assert_includes response.body, "合同挙行"
    assert_includes response.body, "伝道会①"
    assert_includes response.body, "伝道会②"
    assert_includes response.body, "joint_primary_assistant_count"
    assert_includes response.body, "joint_secondary_assistant_count"

    assert_difference "CeremonySchedule.count", 1 do
      assert_difference "CeremonyScheduleFellowship.count", 2 do
        post ceremony_schedules_path, params: {
          event_id: @event.id,
          ceremony_schedule: {
            fellowship_id: saitama.id,
            joint_schedule: "1",
            joint_fellowship_id: yamanashi.id,
            primary_assistant_count: "4",
            secondary_assistant_count: "4",
            primary_spirit_count: "20",
            secondary_spirit_count: "20",
            ceremony_at: "2026-10-25T11:00",
            place: "合同会場",
            minister_name: "合同点伝師"
          }
        }
      end
    end

    schedule = CeremonySchedule.order(:id).last
    assert_predicate schedule, :joint_schedule?
    assert_equal 8, schedule.assistant_count
    assert_equal 40, schedule.spirit_count
    assert_equal "埼玉・山梨（合同）", schedule.display_name
    assert_equal "埼玉4・山梨4", schedule.joint_assistant_breakdown
    assert_equal "埼玉20・山梨20", schedule.joint_spirit_breakdown
    assert_equal [
      { name: "埼玉", assistant_count: 4, spirit_count: 20 },
      { name: "山梨", assistant_count: 4, spirit_count: 20 }
    ], schedule.joint_fellowship_counts
    assert_equal [ [ saitama, 20 ], [ yamanashi, 20 ] ], schedule.allocation_contributions

    get ceremony_schedules_path(event_id: @event.id)

    assert_response :success
    assert_includes response.body, "埼玉・山梨（合同）"
    assert_includes response.body, "8<span class=\"joint-spirit-breakdown\">（埼玉4・山梨4）</span>"
    assert_includes response.body, "40<span class=\"joint-spirit-breakdown\">（埼玉20・山梨20）</span>"
    allocation_section = response.body.split("番号割り振り", 2).last
    assert_includes allocation_section, "埼玉"
    assert_includes allocation_section, "山梨"
    assert_equal 2, allocation_section.scan('value="20"').count
  end

  test "edit form keeps the saved ceremony date in a stable browser format" do
    schedule = CeremonySchedule.create!(
      fellowship: @meeting,
      event: @event,
      ceremony_at: Time.zone.local(2026, 10, 25, 11, 0),
      place: "山梨県甲府市",
      assistant_count: 8,
      spirit_count: 40
    )

    post session_path, params: { login_id: @user.login_id, password: "password123" }
    get edit_ceremony_schedule_path(schedule)

    assert_response :success
    assert_includes response.body, 'value="2026-10-25T11:00"'
  end

  test "admin can add one special schedule without changing regular allocations" do
    seimeiouin = Fellowship.create!(name: "聖明王院", color_code: "#222222", region: @region)
    CeremonySchedule.create!(
      fellowship: @meeting,
      event: @event,
      ceremony_at: Time.zone.local(2026, 10, 20, 10, 0),
      place: "大江戸会館",
      assistant_count: 2,
      spirit_count: 40
    )
    admin = User.create!(
      name: "管理者", email: "admin-special@example.com", password: "password123", password_confirmation: "password123",
      region: @region, admin: true
    )

    post session_path, params: { login_id: admin.login_id, password: "password123" }
    get new_ceremony_schedule_path(event_id: @event.id)
    assert_includes response.body, "聖泉珠院・海外として登録"
    assert_includes response.body, "番号"
    assert_includes response.body, "data-special-serial-total"
    assert_includes response.body, "data-special-spirit-count"

    assert_difference("CeremonySchedule.count", 1) do
      post ceremony_schedules_path, params: {
        event_id: @event.id,
        ceremony_schedule: {
          special_schedule: "1",
          fellowship_id: @meeting.id,
          ceremony_at: "2026-10-18T10:00",
          place: "聖泉珠院",
          assistant_count: "",
          spirit_count: "",
          minister_name: ""
        }
      }
    end

    special_schedule = CeremonySchedule.order(:id).last
    assert_predicate special_schedule, :special_schedule?
    assert_equal seimeiouin, special_schedule.fellowship
    assert_equal "聖明王院", special_schedule.place
    assert_nil special_schedule.assistant_count
    assert_nil special_schedule.spirit_count

    get ceremony_schedules_path(event_id: @event.id)
    assert_includes response.body, "特別</span>海外"
    assert_includes response.body, "special-schedule-location\">聖泉珠院"
    assert_includes response.body, "特別"
    assert_includes response.body, "schedule-row-special"
    assert_includes response.body, ">40<"

    allocation_section = response.body.split("番号割り振り", 2).last
    assert_not_includes allocation_section, "聖泉珠院・海外"

    assert_no_difference("CeremonySchedule.count") do
      post ceremony_schedules_path, params: {
        event_id: @event.id,
        ceremony_schedule: {
          special_schedule: "1",
          ceremony_at: "2026-10-18T11:00",
          place: "海外"
        }
      }
    end
    assert_response :unprocessable_content
  end

  test "schedule can be saved with a date and no time" do
    post session_path, params: { login_id: @user.login_id, password: "password123" }

    assert_difference("CeremonySchedule.count", 1) do
      post ceremony_schedules_path, params: {
        event_id: @event.id,
        ceremony_schedule: {
          fellowship_id: @meeting.id,
          ceremony_at: "2026-05-03T00:00",
          place: "大江戸会館",
          assistant_count: 3,
          spirit_count: 25
        }
      }
    end

    assert_equal Time.zone.local(2026, 5, 3), CeremonySchedule.order(:id).last.ceremony_at
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

  test "admin can distribute the allocation shortfall by altar count" do
    odaiba = Fellowship.create!(name: "お台場", color_code: "#111111", region: @region)
    EventDetail.create!(event: @event, region: @region, total_serial_count: 100)
    CeremonySchedule.create!(
      fellowship: @meeting, event: @event, ceremony_at: Time.zone.local(2026, 5, 1, 10, 30),
      place: "大江戸会館", assistant_count: 1, spirit_count: 20
    )
    CeremonySchedule.create!(
      fellowship: odaiba, event: @event, ceremony_at: Time.zone.local(2026, 5, 2, 10, 30),
      place: "お台場会館", assistant_count: 1, spirit_count: 30
    )
    admin = User.create!(
      name: "管理者", email: "admin@example.com", password: "password123", password_confirmation: "password123",
      region: @region, admin: true
    )

    post session_path, params: { login_id: admin.login_id, password: "password123" }
    post distribute_shortfall_ceremony_schedule_allocations_path, params: { event_id: @event.id }

    assert_redirected_to ceremony_schedules_path(event_id: @event.id)
    assert_equal 37, CeremonyScheduleAllocation.find_by!(event: @event, fellowship: @meeting).spirit_count
    assert_equal 63, CeremonyScheduleAllocation.find_by!(event: @event, fellowship: odaiba).spirit_count

    get ceremony_schedules_path(event_id: @event.id)

    assert_includes response.body, ">100<"
    assert_includes response.body, "（＋17）"
    assert_includes response.body, "（＋33）"

    post undo_distribution_ceremony_schedule_allocations_path, params: { event_id: @event.id }

    assert_redirected_to ceremony_schedules_path(event_id: @event.id)
    assert_equal 50, CeremonyScheduleAllocation.allocated_spirit_count_for(@event)
    assert_equal 0, CeremonyScheduleAllocation.where(event: @event).count
  end
end
