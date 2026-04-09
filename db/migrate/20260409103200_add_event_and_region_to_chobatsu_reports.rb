class AddEventAndRegionToChobatsuReports < ActiveRecord::Migration[8.0]
  def change
    execute <<~SQL
      INSERT INTO regions (id, name, created_at, updated_at)
      SELECT 1, '共通', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
      WHERE NOT EXISTS (SELECT 1 FROM regions WHERE id = 1)
    SQL

    execute <<~SQL
      INSERT INTO events (id, name, created_at, updated_at)
      SELECT 1, '第1回超抜式', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
      WHERE NOT EXISTS (SELECT 1 FROM events WHERE id = 1)
    SQL

    add_reference :chobatsu_reports, :region, null: false, foreign_key: true, default: 1
    add_reference :chobatsu_reports, :event, null: false, foreign_key: true, default: 1
  end
end
