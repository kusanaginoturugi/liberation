class RemoveDefaultsFromChobatsuReports < ActiveRecord::Migration[8.0]
  def change
    change_column_default :chobatsu_reports, :participant_count, from: 0, to: nil
    change_column_default :chobatsu_reports, :merit_fee_total, from: 0, to: nil
  end
end
