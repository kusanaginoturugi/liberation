class AllowNullAssistantNameOnChobatsuReports < ActiveRecord::Migration[8.0]
  def change
    change_column_null :chobatsu_reports, :assistant_name, true
  end
end
