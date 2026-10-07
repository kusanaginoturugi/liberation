class AddJointReportsToChobatsuReports < ActiveRecord::Migration[8.1]
  def change
    add_column :chobatsu_reports, :joint_report, :boolean, null: false, default: false

    create_table :chobatsu_report_fellowships do |t|
      t.references :chobatsu_report, null: false, foreign_key: true
      t.references :fellowship, null: false, foreign_key: true
      t.integer :participant_count, null: false
      t.integer :serial_number_from, null: false
      t.integer :serial_number_to, null: false

      t.timestamps
    end
  end
end
