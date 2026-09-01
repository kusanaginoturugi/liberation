require "application_system_test_case"

class AdminNavigationTest < ApplicationSystemTestCase
  setup do
    region = Region.create!(name: "共通")
    fellowship = Fellowship.create!(name: "大江戸", color_code: "#C8C4C1", region: region)
    Event.create!(name: "第75次修霊超抜式")
    @admin = User.create!(
      name: "管理者",
      email: "admin@example.com",
      password: "password123",
      password_confirmation: "password123",
      region: region,
      fellowship: fellowship,
      admin: true
    )
  end

  test "admin navigation opens and closes from the management button" do
    visit new_session_path
    fill_in "ログインID", with: @admin.login_id
    fill_in "パスワード", with: "password123"
    click_button "ログイン"

    management_button = find("label[for='admin-navigation-toggle']")
    management_menu = ".nav-dropdown--admin .nav-dropdown__menu"

    assert_no_selector management_menu, visible: true

    management_button.click
    assert_selector management_menu, visible: true

    management_button.click
    assert_no_selector management_menu, visible: true

    management_button.click
    within management_menu do
      click_link "超抜式一覧"
    end

    assert_text "超抜式一覧"
    management_button = find("label[for='admin-navigation-toggle']")
    assert_no_selector management_menu, visible: true

    management_button.click
    assert_selector management_menu, visible: true

    management_button.click
    assert_no_selector management_menu, visible: true
  end
end
