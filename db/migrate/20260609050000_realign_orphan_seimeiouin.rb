# frozen_string_literal: true

class RealignOrphanSeimeiouin < ActiveRecord::Migration[8.0]
  # 20260609040200 では name="聖明王院" のレコードがマップ対象に無く
  # OFFSET された 100010 のまま残ってしまった本番個体がある。
  # master の聖明王院は id=88 で配信されるので、sync 時に name UNIQUE で
  # 衝突して 422 になる。先に id を 88 に揃える。
  def up
    execute "PRAGMA defer_foreign_keys = ON"

    return unless select_value("SELECT 1 FROM fellowships WHERE id = 100010 AND name = '聖明王院' LIMIT 1")

    execute "UPDATE chobatsu_reports SET fellowship_id = 88 WHERE fellowship_id = 100010"
    execute "UPDATE fellowships SET id = 88 WHERE id = 100010"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
