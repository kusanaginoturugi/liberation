# frozen_string_literal: true

class AlignFellowshipIdsWithMasters < ActiveRecord::Migration[8.0]
  ID_REMAP = {
    "大江戸" => 18,
    "お台場" => 20,
    "羽田"   => 19,
    "かながわ" => 24,
    "富士山" => 27,
    "駿天"   => 28,
    "埼玉"   => 15,
    "千葉"   => 16,
    "山梨"   => 25
  }.freeze

  OFFSET = 100_000

  def up
    execute "PRAGMA defer_foreign_keys = ON"

    execute "UPDATE chobatsu_reports SET fellowship_id = fellowship_id + #{OFFSET}"
    execute "UPDATE fellowships SET id = id + #{OFFSET}"

    current = select_all("SELECT id, name FROM fellowships").to_a
    current.each do |row|
      new_id = ID_REMAP[row["name"]]
      next unless new_id

      old_id = row["id"]
      execute "UPDATE chobatsu_reports SET fellowship_id = #{new_id} WHERE fellowship_id = #{old_id}"
      execute "UPDATE fellowships SET id = #{new_id} WHERE id = #{old_id}"
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
