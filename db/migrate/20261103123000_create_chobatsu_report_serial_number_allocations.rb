class CreateChobatsuReportSerialNumberAllocations < ActiveRecord::Migration[8.1]
  class MigrationReport < ApplicationRecord
    self.table_name = "chobatsu_reports"

    has_many :serial_number_ranges, class_name: "CreateChobatsuReportSerialNumberAllocations::MigrationRange", foreign_key: :chobatsu_report_id
    has_many :report_fellowships, class_name: "CreateChobatsuReportSerialNumberAllocations::MigrationReportFellowship", foreign_key: :chobatsu_report_id
  end

  class MigrationRange < ApplicationRecord
    self.table_name = "serial_number_ranges"
  end

  class MigrationReportFellowship < ApplicationRecord
    self.table_name = "chobatsu_report_fellowships"

    has_many :additional_ranges, class_name: "CreateChobatsuReportSerialNumberAllocations::MigrationFellowshipRange", foreign_key: :chobatsu_report_fellowship_id
  end

  class MigrationFellowshipRange < ApplicationRecord
    self.table_name = "chobatsu_report_fellowship_serial_number_ranges"
  end

  def up
    create_table :chobatsu_report_serial_number_allocations do |t|
      t.references :chobatsu_report, null: false, foreign_key: true
      t.references :event, null: false, foreign_key: true
      t.references :fellowship, null: false, foreign_key: true
      t.integer :serial_number, null: false
      t.timestamps
    end
    add_index :chobatsu_report_serial_number_allocations,
              [ :event_id, :fellowship_id, :serial_number ],
              unique: true,
              name: "idx_report_allocations_event_fellowship_number"

    MigrationReport.find_each do |report|
      contributions = report.report_fellowships.any? ? report.report_fellowships.map { |item| [ item.fellowship_id, item.serial_number_from, item.serial_number_to, item.additional_ranges ] } : [ [ report.fellowship_id, report.serial_number_from, report.serial_number_to, report.serial_number_ranges ] ]
      rows = contributions.flat_map do |fellowship_id, from, to, additional_ranges|
        ranges = [ [ from, to ] ] + additional_ranges.map { |range| [ range.serial_number_from, range.serial_number_to ] }
        ranges.flat_map do |range_from, range_to|
          (range_from..range_to).map do |serial_number|
            { chobatsu_report_id: report.id, event_id: report.event_id, fellowship_id: fellowship_id, serial_number: serial_number, created_at: Time.current, updated_at: Time.current }
          end
        end
      end
      execute_rows(rows)
    end
  end

  def down
    drop_table :chobatsu_report_serial_number_allocations
  end

  private

  def execute_rows(rows)
    rows.each_slice(500) do |batch|
      MigrationAllocation.insert_all!(batch)
    end
  end

  class MigrationAllocation < ApplicationRecord
    self.table_name = "chobatsu_report_serial_number_allocations"
  end
end
