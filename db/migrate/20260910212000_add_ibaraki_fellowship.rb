class AddIbarakiFellowship < ActiveRecord::Migration[8.1]
  def up
    region = Region.find_or_create_by!(name: "共通")
    fellowship = Fellowship.find_or_initialize_by(name: "茨城")

    fellowship.region ||= region
    fellowship.active = true
    fellowship.enabled = true
    fellowship.display_order ||= 95
    fellowship.save!
  end

  def down
    Fellowship.find_by(name: "茨城")&.destroy!
  end
end
