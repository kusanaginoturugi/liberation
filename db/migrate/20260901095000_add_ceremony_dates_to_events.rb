class AddCeremonyDatesToEvents < ActiveRecord::Migration[8.1]
  def up
    add_column :events, :judgment_ceremony_on, :date
    add_column :events, :chobatsu_starts_on, :date
    add_column :events, :chobatsu_ends_on, :date

    execute <<~SQL.squish
      UPDATE events
      SET judgment_ceremony_on = '2026-10-18',
          chobatsu_starts_on = '2026-10-18',
          chobatsu_ends_on = '2026-12-01'
      WHERE name = '第75次超抜式'
    SQL
  end

  def down
    remove_column :events, :chobatsu_ends_on
    remove_column :events, :chobatsu_starts_on
    remove_column :events, :judgment_ceremony_on
  end
end
