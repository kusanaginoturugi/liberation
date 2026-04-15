require "test_helper"

class UserTest < ActiveSupport::TestCase
  setup do
    @region = Region.create!(name: "共通")
  end

  test "email is normalized and password is secured" do
    user = User.create!(
      name: "管理者",
      email: " ＡＤＭＩＮ＠ＥＸＡＭＰＬＥ．ＣＯＭ ",
      password: "password123",
      password_confirmation: "password123",
      region: @region,
      admin: true
    )

    assert_equal "admin@example.com", user.email
    assert_equal user.id.to_s, user.login_id
    assert user.authenticate("password123")
    assert user.admin?
  end

  test "email must be a valid address after normalization" do
    user = User.new(
      name: "管理者",
      email: "全角だけ",
      password: "password123",
      password_confirmation: "password123",
      region: @region
    )

    assert_not user.valid?
    assert_includes user.errors[:email], "is invalid"
  end

  test "login id is auto assigned for new users" do
    user = User.create!(
      name: "一般",
      email: "member@example.com",
      password: "password123",
      password_confirmation: "password123",
      region: @region
    )

    assert_equal user.id.to_s, user.login_id
  end
end
