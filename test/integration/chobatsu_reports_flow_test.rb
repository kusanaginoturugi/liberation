require "test_helper"

class ChobatsuReportsFlowTest < ActionDispatch::IntegrationTest
  setup do
    SystemSetting.create!(key: SystemSetting::TOTAL_SERIAL_COUNT_KEY, value: "1667")
    @region = Region.create!(name: "共通")
    @meeting = EvangelismMeeting.create!(name: "大江戸", color_code: "#C8C4C1", region: @region)
    @user = User.create!(
      name: "管理者",
      email: "admin@example.com",
      password: "password123",
      password_confirmation: "password123",
      region: @region
    )
    post session_path, params: { email: @user.email, password: "password123" }
  end

  test "root page is accessible" do
    EvangelismMeeting.create!(name: "旧会場", color_code: "#999999", active: false, display_order: 99, region: @region)
    other_region = Region.create!(name: "札幌")
    EvangelismMeeting.create!(name: "札幌会場", color_code: "#111111", region: other_region)

    get root_path

    assert_response :success
    assert_includes response.body, "超抜報告"
    assert_includes response.body, "修霊合計数"
    assert_includes response.body, "超抜報告を登録"
    assert_includes response.body, "大江戸"
    assert_includes response.body, "旧会場"
    assert_includes response.body, "現在は選択不可"
    assert_includes response.body, "札幌"
    assert_not_includes response.body, "札幌会場"
  end

  test "root page switches displayed reports by region" do
    other_region = Region.create!(name: "札幌")
    other_meeting = EvangelismMeeting.create!(name: "札幌会場", color_code: "#111111", region: other_region)
    ChobatsuReport.create!(
      ceremony_date: Date.current,
      evangelism_meeting: other_meeting,
      assistant_name: "札幌担当",
      participant_count: 1,
      serial_number_from: 50,
      serial_number_to: 50,
      merit_fee_total: 5000
    )

    get root_path, params: { region_id: other_region.id }

    assert_response :success
    assert_includes response.body, "札幌会場"
    assert_not_includes response.body, "大江戸"
    assert_includes response.body, ">50<"
  end

  test "creating a report saves the record" do
    assert_difference("ChobatsuReport.count", 1) do
      post chobatsu_reports_path, params: {
        chobatsu_report: {
          ceremony_date: Date.current,
          evangelism_meeting_id: @meeting.id,
          assistant_name: "山田",
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
  end

  test "overlapping range is rejected" do
    ChobatsuReport.create!(
      ceremony_date: Date.current,
      evangelism_meeting: @meeting,
      assistant_name: "既存",
      participant_count: 2,
      serial_number_from: 10,
      serial_number_to: 12,
      merit_fee_total: 2500
    )

    assert_no_difference("ChobatsuReport.count") do
      post chobatsu_reports_path, params: {
        chobatsu_report: {
          ceremony_date: Date.current,
          evangelism_meeting_id: @meeting.id,
          assistant_name: "新規",
          participant_count: 1,
          serial_number_from: 12,
          serial_number_to: 15
        }
      }
    end

    assert_response :unprocessable_content
    assert_includes response.body, "重複しています"
  end

  test "missing required numeric fields show errors" do
    assert_no_difference("ChobatsuReport.count") do
      post chobatsu_reports_path, params: {
        chobatsu_report: {
          ceremony_date: Date.current,
          evangelism_meeting_id: @meeting.id,
          assistant_name: "未入力"
        }
      }
    end

    assert_response :unprocessable_content
    assert_includes response.body, "Participant count can&#39;t be blank"
    assert_includes response.body, "Serial number from can&#39;t be blank"
    assert_includes response.body, "Serial number to can&#39;t be blank"
  end
end
