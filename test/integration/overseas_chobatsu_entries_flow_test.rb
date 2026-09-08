require "test_helper"

class OverseasChobatsuEntriesFlowTest < ActionDispatch::IntegrationTest
  setup do
    @region = Region.create!(name: "共通")
    @event = Event.create!(name: "第75次修霊超抜式")
    @fellowship = Fellowship.create!(name: "大江戸", color_code: "#C8C4C1", region: @region)
    @other_fellowship = Fellowship.create!(name: "お台場", color_code: "#111111", region: @region)
    @third_fellowship = Fellowship.create!(name: "羽田", color_code: "#222222", region: @region)
    CeremonySchedule.create!(
      event: @event, special_schedule: true, ceremony_at: Time.zone.local(2026, 10, 18, 11), place: "聖明王院",
      serial_number_from: 1, serial_number_to: 6
    )
    @user = User.create!(
      name: "大江戸担当者", email: "oedo@example.com", password: "password123", password_confirmation: "password123",
      region: @region, fellowship: @fellowship
    )
    @admin = User.create!(
      name: "管理者", email: "admin-overseas@example.com", password: "password123", password_confirmation: "password123",
      region: @region, admin: true
    )
  end

  test "fellowship user enters names without choosing numbers" do
    other_entry = OverseasChobatsuEntry.create!(event: @event, fellowship: @other_fellowship, assistant_name: "お台場担当者", notes: "確認済み")
    post session_path, params: { login_id: @user.login_id, password: "password123" }

    get overseas_chobatsu_entries_path(event_id: @event.id)

    assert_response :success
    assert_includes response.body, "氏名"
    assert_includes response.body, "備考"
    assert_includes response.body, "番号名簿"
    assert_not_includes response.body, "entries[new-0][serial_number]"
    assert_not_includes response.body, "entries[#{other_entry.id}][assistant_name]"

    patch bulk_update_overseas_chobatsu_entries_path(event_id: @event.id), params: {
      entries: {
        "new-0" => { assistant_name: "尾ノ上裕美", notes: "渡航手続き中" },
        other_entry.id.to_s => { assistant_name: "書き換え不可", notes: "" }
      }
    }

    assert_redirected_to overseas_chobatsu_entries_path(event_id: @event.id)
    entry = OverseasChobatsuEntry.find_by!(event: @event, fellowship: @fellowship, assistant_name: "尾ノ上裕美")
    assert_equal "渡航手続き中", entry.notes
    assert_equal "お台場担当者", other_entry.reload.assistant_name

    patch bulk_update_overseas_chobatsu_entries_path(event_id: @event.id), params: { deleted_entry_ids: [ entry.id ] }

    assert_nil OverseasChobatsuEntry.find_by(id: entry.id)
  end

  test "admin can fill blank numbers automatically, adjust one, and reset the list" do
    first = OverseasChobatsuEntry.create!(event: @event, fellowship: @fellowship, assistant_name: "尾ノ上裕美")
    second = OverseasChobatsuEntry.create!(event: @event, fellowship: @other_fellowship, assistant_name: "尾ノ上卓朗")
    third = OverseasChobatsuEntry.create!(event: @event, fellowship: @third_fellowship, assistant_name: "友田由美")
    post session_path, params: { login_id: @admin.login_id, password: "password123" }

    get overseas_chobatsu_entries_path(event_id: @event.id, fellowship_id: @fellowship.id)

    assert_response :success
    assert_includes response.body, "1"
    assert_includes response.body, "6"
    assert_includes response.body, "assignments[2]"
    assert_includes response.body, "自動割り振り"
    assert_includes response.body, "自動配分に戻す"
    assert_not_includes response.body, "未割り当て"
    assert_match(/name="assignments\[1\]".*?option selected="selected" value="#{first.id}"/m, response.body)
    assert_match(/name="assignments\[2\]".*?option selected="selected" value="#{second.id}"/m, response.body)
    assert_match(/name="assignments\[3\]".*?option selected="selected" value="#{third.id}"/m, response.body)

    post auto_fill_assignments_overseas_chobatsu_entries_path(event_id: @event.id)

    assert_redirected_to overseas_chobatsu_entries_path(event_id: @event.id)
    assert_equal first, OverseasChobatsuAssignment.find_by!(event: @event, serial_number: 4).overseas_chobatsu_entry
    assert_equal second, OverseasChobatsuAssignment.find_by!(event: @event, serial_number: 5).overseas_chobatsu_entry
    assert_equal third, OverseasChobatsuAssignment.find_by!(event: @event, serial_number: 6).overseas_chobatsu_entry

    patch update_assignments_overseas_chobatsu_entries_path(event_id: @event.id), params: { assignments: { "2" => third.id } }

    assert_redirected_to overseas_chobatsu_entries_path(event_id: @event.id)
    assert_equal third, OverseasChobatsuAssignment.find_by!(event: @event, serial_number: 2).overseas_chobatsu_entry
    assert_predicate first, :persisted?
    assert_equal second, OverseasChobatsuEntry.find(second.id)

    post reset_assignments_overseas_chobatsu_entries_path(event_id: @event.id)

    assert_redirected_to overseas_chobatsu_entries_path(event_id: @event.id)
    assert_equal 0, OverseasChobatsuAssignment.where(event: @event).count
  end

  test "overseas PDF returns configuration error when PDF service is unavailable" do
    post session_path, params: { login_id: @user.login_id, password: "password123" }

    get export_overseas_chobatsu_entries_path(event_id: @event.id)

    assert_response :service_unavailable
    assert_includes response.body, "Cloudflare PDFの設定がありません"
  end
end
