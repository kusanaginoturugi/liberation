require "test_helper"

class ChobatsuReportsFlowTest < ActionDispatch::IntegrationTest
  setup do
    @region = Region.create!(name: "共通")
    @event = Event.create!(name: "第1回超抜式")
    @next_event = Event.create!(name: "第2回超抜式")
    EventDetail.create!(event: @event, region: @region, total_serial_count: 1667)
    EventDetail.create!(event: @next_event, region: @region, total_serial_count: 1667)
    @meeting = Fellowship.create!(name: "大江戸", color_code: "#C8C4C1", region: @region, enabled: true)
    @user = User.create!(
      name: "管理者",
      email: "admin@example.com",
      password: "password123",
      password_confirmation: "password123",
      region: @region
    )
    post session_path, params: { login_id: @user.login_id, password: "password123" }
  end

  test "root page is accessible" do
    Fellowship.create!(name: "旧会場", color_code: "#999999", active: false, display_order: 99, region: @region, enabled: true)
    other_region = Region.create!(name: "札幌")
    Fellowship.create!(name: "札幌会場", color_code: "#111111", region: other_region, enabled: true)
    ChobatsuReport.create!(
      ceremony_date: Date.current,
      region: @region,
      event: @event,
      fellowship: @meeting,
      participant_count: 2,
      serial_number_from: 1,
      serial_number_to: 3,
      merit_fee_total: 15000
    )

    get root_path

    assert_response :success
    assert_includes response.body, "修霊番号一覧"
    assert_includes response.body, "対象聖院"
    assert_includes response.body, @region.name
    assert_includes response.body, "合格霊数"
    assert_includes response.body, "挙行報告"
    assert_includes response.body, "大江戸"
    assert_includes response.body, "第2回超抜式"
    assert_includes response.body, "旧会場"
    assert_includes response.body, "現在は選択不可"
    assert_includes response.body, "超抜済"
    assert_includes response.body, "残霊数"
    assert_includes response.body, ">3<"
    assert_includes response.body, ">1664<"
    assert_not_includes response.body, "札幌会場"
    assert_not_includes response.body, "<label for=\"region_id\">聖院</label>"
    assert_includes response.body, "<label for=\"event_id\">超抜式</label>"
  end

  test "root page switches displayed reports by event in single region mode" do
    other_region = Region.create!(name: "札幌")
    EventDetail.create!(event: @event, region: other_region, total_serial_count: 1667)
    other_meeting = Fellowship.create!(name: "札幌会場", color_code: "#111111", region: other_region, enabled: true)
    ChobatsuReport.create!(
      ceremony_date: Date.current,
      region: other_region,
      event: @event,
      fellowship: other_meeting,
      participant_count: 1,
      serial_number_from: 50,
      serial_number_to: 50,
      merit_fee_total: 5000
    )
    ChobatsuReport.create!(
      ceremony_date: Date.current,
      region: @region,
      event: @next_event,
      fellowship: @meeting,
      participant_count: 1,
      serial_number_from: 88,
      serial_number_to: 88,
      merit_fee_total: 5000
    )

    get root_path, params: { region_id: other_region.id, event_id: @next_event.id }

    assert_response :success
    assert_includes response.body, "大江戸"
    assert_not_includes response.body, "札幌会場"
    assert_includes response.body, "--cell-color: #C8C4C1\">88<"
    assert_not_includes response.body, "--cell-color: #111111\">50<"
  end

  test "creating a report saves the record" do
    assert_difference("ChobatsuReport.count", 1) do
      post chobatsu_reports_path, params: {
        chobatsu_report: {
          ceremony_date: Date.current,
          fellowship_id: @meeting.id,
          participant_count: 4,
          serial_number_from: 1,
          serial_number_to: 4
        }
      }
    end

    assert_redirected_to root_path
    follow_redirect!
    assert_includes response.body, "登録しました"
    assert_equal 20000, ChobatsuReport.last.merit_fee_total
    assert_equal @next_event, ChobatsuReport.last.event
    assert_equal @region, ChobatsuReport.last.region
    assert_equal @user, ChobatsuReport.last.user
  end

  test "creating a report saves additional serial number ranges" do
    assert_difference([ "ChobatsuReport.count", "SerialNumberRange.count" ], 1) do
      post chobatsu_reports_path, params: {
        chobatsu_report: {
          ceremony_date: Date.current,
          fellowship_id: @meeting.id,
          participant_count: 2,
          serial_number_from: 10,
          serial_number_to: 12,
          serial_number_ranges_attributes: {
            "0" => { serial_number_from: 20, serial_number_to: 21 }
          }
        }
      }
    end

    report = ChobatsuReport.last
    assert_equal 5, report.usage_count
    assert_equal 25_000, report.merit_fee_total
    assert_equal [ [ 20, 21 ] ], report.serial_number_ranges.pluck(:serial_number_from, :serial_number_to)
  end

  test "creating a joint report keeps fellowship counts and number ranges separate" do
    odaiba = Fellowship.create!(name: "お台場", color_code: "#123456", region: @region, enabled: true)

    assert_difference("ChobatsuReport.count", 1) do
      assert_difference("ChobatsuReportFellowship.count", 2) do
        post chobatsu_reports_path, params: {
          chobatsu_report: {
            ceremony_date: Date.current,
            joint_report: "1",
            joint_primary_fellowship_id: odaiba.id,
            joint_secondary_fellowship_id: @meeting.id,
            joint_primary_participant_count: 10,
            joint_secondary_participant_count: 3,
            joint_primary_serial_number_from: 945,
            joint_primary_serial_number_to: 999,
            joint_secondary_serial_number_from: 1196,
            joint_secondary_serial_number_to: 1265
          }
        }
      end
    end

    report = ChobatsuReport.last
    assert_predicate report, :joint_report?
    assert_equal odaiba, report.fellowship
    assert_equal 13, report.participant_count
    assert_equal 125, report.usage_count
    assert_equal [ "【合同】", "お台場・大江戸" ], report.report_display_name_lines
    assert_equal [ "お台場 10", "大江戸 3" ], report.participant_count_lines
    assert_equal [ "お台場 55", "大江戸 70" ], report.usage_count_lines
    assert_equal [ "お台場 945〜999", "大江戸 1,196〜1,265" ], report.serial_number_range_lines
    assert_equal [ [ odaiba, 945, 999 ], [ @meeting, 1196, 1265 ] ], report.number_range_contributions

    get summary_chobatsu_reports_path, params: { event_id: @next_event.id }

    assert_response :success
    assert_includes response.body, "【合同】"
    assert_includes response.body, "お台場・大江戸"
    assert_includes response.body, "お台場 10"
    assert_includes response.body, "大江戸 3"
    assert_includes response.body, "お台場 55"
    assert_includes response.body, "大江戸 70"

    patch chobatsu_report_path(report), params: {
      chobatsu_report: {
        ceremony_date: Date.current,
        joint_report: "1",
        joint_primary_fellowship_id: odaiba.id,
        joint_secondary_fellowship_id: @meeting.id,
        joint_primary_participant_count: 11,
        joint_secondary_participant_count: 4,
        joint_primary_serial_number_from: 945,
        joint_primary_serial_number_to: 1000,
        joint_secondary_serial_number_from: 1196,
        joint_secondary_serial_number_to: 1266
      }
    }

    assert_redirected_to summary_chobatsu_reports_path(event_id: @next_event.id)
    report.reload
    assert_equal 15, report.participant_count
    assert_equal [ "お台場 11", "大江戸 4" ], report.participant_count_lines
    assert_equal [ "お台場 945〜1,000", "大江戸 1,196〜1,266" ], report.serial_number_range_lines
  end

  test "creating a joint report saves added number ranges for each fellowship" do
    odaiba = Fellowship.create!(name: "お台場", color_code: "#123456", region: @region, enabled: true)

    assert_difference("ChobatsuReportFellowshipSerialNumberRange.count", 2) do
      post chobatsu_reports_path, params: {
        chobatsu_report: {
          ceremony_date: Date.current,
          joint_report: "1",
          joint_primary_fellowship_id: odaiba.id,
          joint_secondary_fellowship_id: @meeting.id,
          joint_primary_participant_count: 10,
          joint_secondary_participant_count: 3,
          joint_primary_serial_number_from: 1,
          joint_primary_serial_number_to: 50,
          joint_primary_additional_ranges_attributes: {
            "0" => { serial_number_from: 82, serial_number_to: 91 }
          },
          joint_secondary_serial_number_from: 101,
          joint_secondary_serial_number_to: 101,
          joint_secondary_additional_ranges_attributes: {
            "0" => { serial_number_from: 150, serial_number_to: 202 }
          }
        }
      }
    end

    report = ChobatsuReport.last
    assert_equal 114, report.usage_count
    assert_equal [ "お台場 1〜50、82〜91", "大江戸 101〜101、150〜202" ], report.serial_number_range_lines
    assert_equal [ "お台場 60", "大江戸 54" ], report.usage_count_lines
    assert_equal [ [ odaiba, 1, 50 ], [ odaiba, 82, 91 ], [ @meeting, 101, 101 ], [ @meeting, 150, 202 ] ], report.number_range_contributions
  end

  test "summary page shows registered report data" do
    report = ChobatsuReport.create!(
      ceremony_date: Date.new(2026, 4, 9),
      region: @region,
      event: @event,
      user: @user,
      fellowship: @meeting,
      participant_count: 2,
      serial_number_from: 1,
      serial_number_to: 4,
      merit_fee_total: 20000
    )

    get summary_chobatsu_reports_path, params: { event_id: @event.id }

    assert_response :success
    assert_includes response.body, "挙行一覧"
    assert_includes response.body, "対象聖院"
    assert_includes response.body, @region.name
    assert_includes response.body, "対象超抜式"
    assert_includes response.body, @event.name
    assert_includes response.body, "CSV出力"
    assert_includes response.body, "UTF-8(BOM)"
    assert_includes response.body, "SJIS"
    assert_includes response.body, "PDF出力"
    assert_includes response.body, "2026/04/09"
    assert_includes response.body, @meeting.name
    assert_includes response.body, "超抜引保師数"
    assert_includes response.body, "超抜霊数"
    assert_includes response.body, ">2<"
    assert_includes response.body, ">4<"
    assert_includes response.body, ">20,000<"
    assert_includes response.body, ">13,000<"
    assert_includes response.body, ">3,000<"
    assert_includes response.body, @user.name
    assert_equal report.user, @user
  end

  test "summary page groups by evangelism meeting by default" do
    @meeting.update!(display_order: 2)
    first_meeting = Fellowship.create!(name: "一番会場", color_code: "#111111", display_order: 1, region: @region, enabled: true)

    ChobatsuReport.create!(
      ceremony_date: Date.new(2026, 4, 10),
      region: @region,
      event: @event,
      user: @user,
      fellowship: @meeting,
      participant_count: 1,
      serial_number_from: 1,
      serial_number_to: 1,
      merit_fee_total: 5000
    )
    ChobatsuReport.create!(
      ceremony_date: Date.new(2026, 4, 8),
      region: @region,
      event: @event,
      user: @user,
      fellowship: first_meeting,
      participant_count: 1,
      serial_number_from: 2,
      serial_number_to: 2,
      merit_fee_total: 5000
    )

    get summary_chobatsu_reports_path, params: { event_id: @event.id }

    assert_response :success
    assert_operator response.body.index(first_meeting.name), :<, response.body.index(@meeting.name)
    assert_includes response.body, "伝道会名"
    assert_includes response.body, "▼"
  end

  test "summary page sorts by ceremony date" do
    older_report = ChobatsuReport.create!(
      ceremony_date: Date.new(2026, 4, 8),
      region: @region,
      event: @event,
      user: @user,
      fellowship: @meeting,
      participant_count: 1,
      serial_number_from: 1,
      serial_number_to: 1,
      merit_fee_total: 5000
    )
    newer_report = ChobatsuReport.create!(
      ceremony_date: Date.new(2026, 4, 10),
      region: @region,
      event: @event,
      user: @user,
      fellowship: @meeting,
      participant_count: 1,
      serial_number_from: 2,
      serial_number_to: 2,
      merit_fee_total: 5000
    )

    get summary_chobatsu_reports_path, params: { event_id: @event.id, sort: :ceremony_date }

    assert_response :success
    ascending_dates = response.body.scan(%r{<td[^>]*>(\d{4}/\d{2}/\d{2})</td>}).flatten
    assert_equal [ older_report.ceremony_date.strftime("%Y/%m/%d"), newer_report.ceremony_date.strftime("%Y/%m/%d") ],
                 ascending_dates.first(2)
    assert_includes response.body, "挙行日"
    assert_includes response.body, "▼"

    get summary_chobatsu_reports_path, params: { event_id: @event.id, sort: :ceremony_date, direction: :desc }

    assert_response :success
    descending_dates = response.body.scan(%r{<td[^>]*>(\d{4}/\d{2}/\d{2})</td>}).flatten
    assert_equal [ newer_report.ceremony_date.strftime("%Y/%m/%d"), older_report.ceremony_date.strftime("%Y/%m/%d") ],
                 descending_dates.first(2)
    assert_includes response.body, "▲"
  end

  test "past event reports cannot be edited or deleted" do
    report = ChobatsuReport.create!(
      ceremony_date: Date.current,
      region: @region,
      event: @event,
      fellowship: @meeting,
      user: @user,
      participant_count: 1,
      serial_number_from: 1,
      serial_number_to: 1,
      merit_fee_total: 5000
    )
    @event.update!(closed: true)
    @next_event.update!(closed: false)

    get summary_chobatsu_reports_path, params: { event_id: @event.id }

    assert_response :success
    assert_not_includes response.body, "操作"
    assert_not_includes response.body, "編集"
    assert_not_includes response.body, "削除"

    get edit_chobatsu_report_path(report)

    assert_redirected_to summary_chobatsu_reports_path(event_id: @event.id)
  end

  test "new page shows refund summary fields" do
    get new_chobatsu_report_path

    assert_response :success
    assert_includes response.body, "CSV出力"
    assert_includes response.body, "UTF-8(BOM)"
    assert_includes response.body, "SJIS"
    assert_includes response.body, "PDF出力"
    assert_includes response.body, "対象超抜式"
    assert_includes response.body, @next_event.name
    assert_includes response.body, "みろく寺分"
    assert_includes response.body, "聖院還付金"
    assert_not_includes response.body, 'name="chobatsu_report[event_id]"'
  end

  test "new page recreates missing event detail and keeps numeric max usable" do
    EventDetail.delete_all
    primary_region = Region.find(Rails.configuration.x.primary_region_id)

    get new_chobatsu_report_path

    assert_response :success
    assert_includes response.body, 'name="chobatsu_report[serial_number_from]"'
    assert_includes response.body, 'max="1667"'
    assert_equal 1, EventDetail.where(event: @next_event, region: primary_region).count
  end

  test "report form prepopulates details from a ceremony schedule" do
    schedule = CeremonySchedule.create!(
      fellowship: @meeting,
      event: @next_event,
      ceremony_at: Time.zone.local(2026, 10, 25, 11, 0),
      place: "大江戸会館",
      assistant_count: 4,
      spirit_count: 40
    )

    get new_chobatsu_report_path, params: { ceremony_schedule_id: schedule.id }

    assert_response :success
    assert_includes response.body, 'name="chobatsu_report[ceremony_schedule_id]"'
    assert_includes response.body, "value=\"#{schedule.id}\""
    assert_includes response.body, 'value="2026-10-25"'
    assert_includes response.body, "<option selected=\"selected\" value=\"#{@meeting.id}\">#{@meeting.name}</option>"
    assert_includes response.body, 'value="4"'
  end

  test "report page exports csv" do
    ChobatsuReport.create!(
      ceremony_date: Date.new(2026, 4, 9),
      region: @region,
      event: @event,
      user: @user,
      fellowship: @meeting,
      participant_count: 2,
      serial_number_from: 1,
      serial_number_to: 4,
      merit_fee_total: 20000
    )

    get export_chobatsu_reports_path(format: :csv, event_id: @event.id, encoding: :utf8)

    assert_response :success
    assert_equal "text/csv", response.media_type
    assert_includes response.body, "挙行日,伝道会名,超抜引保師数,超抜霊数"
    assert_includes response.body, "2026/04/09"
    assert_includes response.body, @meeting.name
    assert_includes response.body, "2026/04/09,#{@meeting.name},2,4"
  end

  test "report page exports csv with utf-8 bom" do
    ChobatsuReport.create!(
      ceremony_date: Date.new(2026, 4, 9),
      region: @region,
      event: @event,
      user: @user,
      fellowship: @meeting,
      participant_count: 2,
      serial_number_from: 1,
      serial_number_to: 4,
      merit_fee_total: 20000
    )

    get export_chobatsu_reports_path(format: :csv, event_id: @event.id, encoding: :utf8_bom)

    assert_response :success
    assert_equal "text/csv", response.media_type
    assert response.body.start_with?("\uFEFF")
  end

  test "report page exports csv with sjis" do
    ChobatsuReport.create!(
      ceremony_date: Date.new(2026, 4, 9),
      region: @region,
      event: @event,
      user: @user,
      fellowship: @meeting,
      participant_count: 2,
      serial_number_from: 1,
      serial_number_to: 4,
      merit_fee_total: 20000
    )

    get export_chobatsu_reports_path(format: :csv, event_id: @event.id, encoding: :sjis)

    assert_response :success
    assert_equal "text/csv", response.media_type
    assert_equal Encoding::Windows_31J, response.body.encoding
  end

  test "report page exports printable html for pdf button" do
    ChobatsuReport.create!(
      ceremony_date: Date.new(2026, 4, 9),
      region: @region,
      event: @event,
      user: @user,
      fellowship: @meeting,
      participant_count: 2,
      serial_number_from: 1,
      serial_number_to: 4,
      merit_fee_total: 20000
    )

    get export_chobatsu_reports_path(event_id: @event.id, region_id: @region.id)

    assert_response :success
    assert_equal "text/html", response.media_type
    assert_includes response.body, "挙行報告"
    assert_includes response.body, "超抜引保師数"
    assert_includes response.body, "超抜霊数"
    assert_includes response.body, ">2<"
    assert_includes response.body, ">4<"
    assert_includes response.body, "window.print()"
  end

  test "overlapping range is rejected in the same event" do
    ChobatsuReport.create!(
      ceremony_date: Date.current,
      region: @region,
      event: @next_event,
      fellowship: @meeting,
      participant_count: 2,
      serial_number_from: 10,
      serial_number_to: 12,
      merit_fee_total: 15000
    )

    assert_no_difference("ChobatsuReport.count") do
      post chobatsu_reports_path, params: {
        chobatsu_report: {
          ceremony_date: Date.current,
          fellowship_id: @meeting.id,
          participant_count: 1,
          serial_number_from: 12,
          serial_number_to: 15
        }
      }
    end

    assert_response :unprocessable_content
    assert_includes response.body, "重複しています"
  end

  test "same range can be used in another event" do
    ChobatsuReport.create!(
      ceremony_date: Date.current,
      region: @region,
      event: @event,
      fellowship: @meeting,
      participant_count: 2,
      serial_number_from: 10,
      serial_number_to: 12,
      merit_fee_total: 10000
    )

    assert_difference("ChobatsuReport.count", 1) do
      post chobatsu_reports_path, params: {
        chobatsu_report: {
          ceremony_date: Date.current,
          fellowship_id: @meeting.id,
          participant_count: 1,
          serial_number_from: 10,
          serial_number_to: 12
        }
      }
    end

    assert_redirected_to root_path
  end

  test "missing required numeric fields show errors" do
    assert_no_difference("ChobatsuReport.count") do
      post chobatsu_reports_path, params: {
        chobatsu_report: {
          ceremony_date: Date.current,
          fellowship_id: @meeting.id
        }
      }
    end

    assert_response :unprocessable_content
    assert_includes response.body, "Participant count can&#39;t be blank"
    assert_includes response.body, "Serial number from can&#39;t be blank"
  end
end
