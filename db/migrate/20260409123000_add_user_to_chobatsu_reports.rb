class AddUserToChobatsuReports < ActiveRecord::Migration[8.0]
  def change
    add_reference :chobatsu_reports, :user, foreign_key: true
  end
end
