namespace :events do
  desc "超抜式を追加し、全聖院の event_details を作成する"
  task :create, [:name] => :environment do |_task, args|
    name = args[:name].to_s.strip

    if name.blank?
      abort "使い方: bin/rails 'events:create[第2回超抜式]'"
    end

    event = Event.find_or_create_by!(name: name)

    Region.order(:id).find_each do |region|
      EventDetail.find_or_create_by!(event: event, region: region) do |detail|
        detail.total_serial_count = 1667
      end
    end

    puts "超抜式を登録しました: #{event.name}"
  end
end
