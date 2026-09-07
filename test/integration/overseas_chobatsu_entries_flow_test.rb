require "test_helper"

class OverseasChobatsuEntriesFlowTest < ActionDispatch::IntegrationTest
  setup do
    @region = Region.create!(name: "共通")
    @event = Event.create!(name: "第75次修霊超抜式")
    @fellowship = Fellowship.create!(name: "大江戸", color_code: "#C8C4C1", region: @region)
    @other_fellowship = Fellowship.create!(name: "お台場", color_code: "#111111", region: @region)
    @user = User.create!(
      name: "大江戸担当者", email: "oedo@example.com", password: "password123", password_confirmation: "password123",
      region: @region, fellowship: @fellowship
    )
  end

  test "signed in fellowship user can add numbered overseas assistants for their fellowship" do
    OverseasChobatsuEntry.create!(
      event: @event, fellowship: @other_fellowship, serial_number: 301, assistant_name: "お台場担当者", notes: "確認済み"
    )
    post session_path, params: { login_id: @user.login_id, password: "password123" }

    get overseas_chobatsu_entries_path(event_id: @event.id)

    assert_response :success
    assert_includes response.body, "海外超抜"
    assert_includes response.body, "番号"
    assert_includes response.body, "引保師名"
    assert_includes response.body, "備考"
    assert_includes response.body, "overseas-chobatsu-table"
    assert_includes response.body, "PDFダウンロード"
    assert_not_includes response.body, "お台場担当者"
    assert_includes response.body, "entries[new-0][assistant_name]"

    patch bulk_update_overseas_chobatsu_entries_path(event_id: @event.id), params: {
      entries: {
        "new-0" => { serial_number: "201", assistant_name: "山田花子", notes: "渡航手続き中" },
        @other_fellowship.id.to_s => { serial_number: "999", assistant_name: "書き換え不可", notes: "" }
      }
    }

    assert_redirected_to overseas_chobatsu_entries_path(event_id: @event.id)
    entry = OverseasChobatsuEntry.find_by!(event: @event, fellowship: @fellowship, serial_number: 201)
    assert_equal "山田花子", entry.assistant_name
    assert_equal "渡航手続き中", entry.notes
    assert_equal "お台場担当者", OverseasChobatsuEntry.find_by!(event: @event, fellowship: @other_fellowship).assistant_name

    patch bulk_update_overseas_chobatsu_entries_path(event_id: @event.id), params: { deleted_entry_ids: [ entry.id ] }

    assert_redirected_to overseas_chobatsu_entries_path(event_id: @event.id)
    assert_nil OverseasChobatsuEntry.find_by(id: entry.id)
    assert_predicate OverseasChobatsuEntry.find_by!(event: @event, fellowship: @other_fellowship), :persisted?
  end

  test "overseas PDF returns configuration error when PDF service is unavailable" do
    post session_path, params: { login_id: @user.login_id, password: "password123" }

    get export_overseas_chobatsu_entries_path(event_id: @event.id)

    assert_response :service_unavailable
    assert_includes response.body, "Cloudflare PDFの設定がありません"
  end
end
