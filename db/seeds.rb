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

rows.each do |row|
  EvangelismMeeting.find_or_initialize_by(name: row.fetch("name")).tap do |meeting|
    meeting.color_code = row.fetch("color_code")
    meeting.display_order = row["display_order"]
    meeting.active = row.key?("active") ? row["active"] : true
    meeting.save!
  end
end

SystemSetting.find_or_initialize_by(key: SystemSetting::TOTAL_SERIAL_COUNT_KEY).tap do |setting|
  setting.value = "1667"
  setting.save!
end
