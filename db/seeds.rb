# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end
meetings = [
  ["大江戸", "#C8C4C1"],
  ["お台場", "#EFB184"],
  ["羽田", "#E88E86"],
  ["かながわ", "#A9D3A9"],
  ["富士山", "#EFD77A"],
  ["駿天", "#8FB6DE"],
  ["埼玉", "#9FD2D6"],
  ["千葉", "#E9AFC2"],
  ["山梨", "#C2B0D9"]
]

meetings.each do |name, color_code|
  EvangelismMeeting.find_or_create_by!(name:) do |meeting|
    meeting.color_code = color_code
  end
end

SystemSetting.find_or_initialize_by(key: SystemSetting::TOTAL_SERIAL_COUNT_KEY).tap do |setting|
  setting.value = "1667"
  setting.save!
end
