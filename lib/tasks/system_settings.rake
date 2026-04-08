namespace :settings do
  desc "Set total serial count. Usage: bin/rails 'settings:set_total_serial_count[1700]'"
  task :set_total_serial_count, [:value] => :environment do |_task, args|
    value = args[:value].to_i

    if args[:value].blank? || value <= 0
      abort "Please provide a positive integer. Example: bin/rails 'settings:set_total_serial_count[1700]'"
    end

    setting = SystemSetting.find_or_initialize_by(key: SystemSetting::TOTAL_SERIAL_COUNT_KEY)
    setting.value = value.to_s
    setting.save!

    puts "Updated total_serial_count to #{setting.value}"
  end
end
