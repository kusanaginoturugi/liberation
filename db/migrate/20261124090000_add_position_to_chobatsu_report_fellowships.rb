class AddPositionToChobatsuReportFellowships < ActiveRecord::Migration[8.1]
  def change
    add_column :chobatsu_report_fellowships, :position, :integer, null: false, default: 0
  end
end
