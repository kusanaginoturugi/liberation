require "test_helper"

class UserTest < ActiveSupport::TestCase
  setup do
    @region = Region.create!(name: "共通")
  end

  test "email is normalized and password is secured" do
    user = User.create!(
      name: "管理者",
      email: " ADMIN@EXAMPLE.COM ",
      password: "password123",
      password_confirmation: "password123",
      region: @region
    )

    assert_equal "admin@example.com", user.email
    assert user.authenticate("password123")
  end
end
