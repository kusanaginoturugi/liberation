class AddAltarCountToFellowships < ActiveRecord::Migration[8.1]
  ALTAR_COUNTS = {
    "大江戸" => 3,
    "お台場" => 6,
    "羽田" => 11,
    "かながわ" => 15,
    "富士山" => 4,
    "駿天" => 3,
    "埼玉" => 8,
    "千葉" => 15,
    "山梨" => 5
  }.freeze

  def up
    add_column :fellowships, :altar_count, :integer, null: false, default: 0

    ALTAR_COUNTS.each do |name, altar_count|
      execute <<~SQL.squish
        UPDATE fellowships
        SET altar_count = #{altar_count}
        WHERE name = #{connection.quote(name)}
      SQL
    end
  end

  def down
    remove_column :fellowships, :altar_count
  end
end
