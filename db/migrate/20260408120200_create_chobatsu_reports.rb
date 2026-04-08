class CreateChobatsuReports < ActiveRecord::Migration[8.0]
  def change
    create_table :chobatsu_reports do |t|
      t.date :ceremony_date, null: false
      t.references :evangelism_meeting, null: false, foreign_key: true
      t.string :assistant_name, null: false
      t.integer :participant_count, null: false, default: 0
      t.integer :serial_number_from, null: false
      t.integer :serial_number_to, null: false
      t.integer :merit_fee_total, null: false, default: 0

      t.timestamps
    end

    add_index :chobatsu_reports, :ceremony_date
    add_index :chobatsu_reports, [:serial_number_from, :serial_number_to]
  end
end
