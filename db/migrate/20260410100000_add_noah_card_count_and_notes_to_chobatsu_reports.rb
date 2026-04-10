class AddNoahCardCountAndNotesToChobatsuReports < ActiveRecord::Migration[8.0]
  def change
    add_column :chobatsu_reports, :noah_card_count, :integer
    add_column :chobatsu_reports, :notes, :text
  end
end
