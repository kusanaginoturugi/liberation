class LimitAvailableFellowships < ActiveRecord::Migration[8.1]
  AVAILABLE_FELLOWSHIPS = [
    "大江戸", "お台場", "羽田", "かながわ", "富士山", "駿天",
    "埼玉", "千葉", "山梨", "聖明王院", "大仏殿"
  ].freeze

  def up
    region = Region.order(:id).first || Region.create!(name: "共通")

    AVAILABLE_FELLOWSHIPS.each_with_index do |name, index|
      fellowship = Fellowship.find_or_initialize_by(name: name)
      fellowship.region ||= region
      fellowship.active = true
      fellowship.enabled = true
      fellowship.display_order = (index + 1) * 10
      fellowship.save!
    end

    Fellowship.where.not(name: AVAILABLE_FELLOWSHIPS).update_all(enabled: false)
  end
end
