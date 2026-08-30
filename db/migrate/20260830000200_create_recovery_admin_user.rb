class CreateRecoveryAdminUser < ActiveRecord::Migration[8.1]
  LOGIN_ID = "admin-recovery-20260830".freeze
  EMAIL = "admin-recovery@liberation.showway.biz".freeze

  def up
    return unless Rails.env.production?

    user = User.find_or_initialize_by(login_id: LOGIN_ID)
    temporary_password = SecureRandom.urlsafe_base64(18)

    user.assign_attributes(
      name: "管理者",
      email: EMAIL,
      region: Region.order(:id).first || Region.create!(name: "共通"),
      admin: true,
      password: temporary_password,
      password_confirmation: temporary_password
    )
    user.save!

    puts "RECOVERY_ADMIN_LOGIN_ID=#{LOGIN_ID}"
    puts "RECOVERY_ADMIN_TEMPORARY_PASSWORD=#{temporary_password}"
  end

  def down
    return unless Rails.env.production?

    User.find_by(login_id: LOGIN_ID)&.destroy!
  end
end
