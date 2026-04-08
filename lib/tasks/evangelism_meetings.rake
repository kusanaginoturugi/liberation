require "yaml"

namespace :meetings do
  desc "Sync evangelism meetings from YAML. Usage: bin/rails 'meetings:sync[config/meetings.yml]'"
  task :sync, [:path] => :environment do |_task, args|
    path = args[:path].presence || "config/meetings.yml"
    config = YAML.load_file(Rails.root.join(path))
    rows = config.fetch("meetings")

    ActiveRecord::Base.transaction do
      incoming_names = rows.map { |row| row.fetch("name") }

      rows.each do |row|
        meeting = EvangelismMeeting.find_or_initialize_by(name: row.fetch("name"))
        meeting.color_code = row.fetch("color_code")
        meeting.display_order = row["display_order"]
        meeting.active = row.key?("active") ? row["active"] : true
        meeting.save!
      end

      EvangelismMeeting.where.not(name: incoming_names).update_all(active: false)
    end

    puts "Synced #{rows.size} evangelism meetings from #{path}"
  end
end
