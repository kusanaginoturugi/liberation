# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end
rows = YAML.load_file(Rails.root.join("config/meetings.yml")).fetch("meetings")

default_region = Region.find_or_create_by!(name: "共通")
default_event = Event.find_or_create_by!(name: "第1回超抜式")

rows.each do |row|
  EvangelismMeeting.find_or_initialize_by(name: row.fetch("name")).tap do |meeting|
    meeting.region = Region.find_or_create_by!(name: row.fetch("region_name", "共通"))
    meeting.color_code = row.fetch("color_code")
    meeting.display_order = row["display_order"]
    meeting.active = row.key?("active") ? row["active"] : true
    meeting.save!
  end
end

Region.order(:id).find_each do |region|
  EventDetail.find_or_create_by!(event: default_event, region: region) do |detail|
    detail.total_serial_count = 1667
  end
end

SystemSetting.find_or_initialize_by(key: SystemSetting::GRADIENT_ENABLED_KEY).tap do |setting|
  setting.value = "true"
  setting.save!
end

SystemSetting.find_or_initialize_by(key: SystemSetting::NUMBER_SHADOW_ENABLED_KEY).tap do |setting|
  setting.value = "false"
  setting.save!
end

User.find_or_initialize_by(email: "admin@example.com").tap do |user|
  user.name = "管理者"
  user.region = default_region
  user.admin = true
  if user.new_record?
    user.password = "password123"
    user.password_confirmation = "password123"
  end
  user.save!
end
