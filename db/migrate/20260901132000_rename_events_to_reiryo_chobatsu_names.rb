class RenameEventsToReiryoChobatsuNames < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL.squish
      UPDATE events
      SET name = REPLACE(name, '次超抜式', '次修霊超抜式')
      WHERE name LIKE '%次超抜式'
    SQL
  end

  def down
    execute <<~SQL.squish
      UPDATE events
      SET name = REPLACE(name, '次修霊超抜式', '次超抜式')
      WHERE name LIKE '%次修霊超抜式'
    SQL
  end
end
