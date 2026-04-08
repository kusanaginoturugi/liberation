require "test_helper"

class ChobatsuReportsFlowTest < ActionDispatch::IntegrationTest
  setup do
    SystemSetting.create!(key: SystemSetting::TOTAL_SERIAL_COUNT_KEY, value: "1667")
    @meeting = EvangelismMeeting.create!(name: "大江戸", color_code: "#C8C4C1")
  end

  test "root page is accessible" do
    get root_path

    assert_response :success
    assert_includes response.body, "超抜報告"
    assert_includes response.body, "修霊合計数"
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
