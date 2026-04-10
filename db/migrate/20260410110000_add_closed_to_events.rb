class AddClosedToEvents < ActiveRecord::Migration[8.0]
  def change
    add_column :events, :closed, :boolean, null: false, default: false
  end
end
