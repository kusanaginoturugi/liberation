class CreateChobatsuReportFellowshipSerialNumberRanges < ActiveRecord::Migration[8.1]
  def change
    create_table :chobatsu_report_fellowship_serial_number_ranges do |t|
      t.references :chobatsu_report_fellowship, null: false, foreign_key: true
      t.integer :serial_number_from, null: false
      t.integer :serial_number_to, null: false

      t.timestamps
    end
  end
end
