require "test_helper"

class ChobatsuReportTest < ActiveSupport::TestCase
  setup do
    SystemSetting.create!(key: SystemSetting::TOTAL_SERIAL_COUNT_KEY, value: "1667")
    @meeting = EvangelismMeeting.create!(name: "大江戸", color_code: "#C8C4C1")
  end

  test "usage_count is calculated from serial number range" do
    report = ChobatsuReport.new(
      ceremony_date: Date.current,
      evangelism_meeting: @meeting,
      assistant_name: "田中",
      participant_count: 3,
      serial_number_from: 10,
      serial_number_to: 15,
      merit_fee_total: 5000
    )

    assert_equal 6, report.usage_count
  end

  test "merit_fee_total is calculated from participant_count" do
    report = ChobatsuReport.create!(
      ceremony_date: Date.current,
      evangelism_meeting: @meeting,
      assistant_name: "田中",
      participant_count: 3,
      serial_number_from: 10,
      serial_number_to: 15,
      merit_fee_total: 1
    )

    assert_equal 15000, report.merit_fee_total
    assert_equal 15000, report.calculated_merit_fee_total
  end

  test "participant_count and serial range are required" do
    report = ChobatsuReport.new(
      ceremony_date: Date.current,
      evangelism_meeting: @meeting,
      assistant_name: "未入力"
    )

    assert_not report.valid?
    assert_includes report.errors[:participant_count], "can't be blank"
    assert_includes report.errors[:serial_number_from], "can't be blank"
    assert_includes report.errors[:serial_number_to], "can't be blank"
  end

  test "serial number ranges cannot overlap" do
    ChobatsuReport.create!(
      ceremony_date: Date.current,
      evangelism_meeting: @meeting,
      assistant_name: "先行登録",
      participant_count: 2,
      serial_number_from: 20,
      serial_number_to: 25,
      merit_fee_total: 3000
    )

    overlap_report = ChobatsuReport.new(
      ceremony_date: Date.current,
      evangelism_meeting: @meeting,
      assistant_name: "重複登録",
      participant_count: 1,
      serial_number_from: 25,
      serial_number_to: 30,
      merit_fee_total: 2000
    )

    assert_not overlap_report.valid?
    assert_includes overlap_report.errors.full_messages.join, "重複"
  end

  test "serial number upper bound must be within total count" do
    report = ChobatsuReport.new(
      ceremony_date: Date.current,
      evangelism_meeting: @meeting,
      assistant_name: "上限超過",
      participant_count: 1,
      serial_number_from: 1660,
      serial_number_to: 1668,
      merit_fee_total: 1000
    )

    assert_not report.valid?
    assert_includes report.errors[:serial_number_to].join, "1667"
  end
end
