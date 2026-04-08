class AddActiveAndDisplayOrderToEvangelismMeetings < ActiveRecord::Migration[8.0]
  def change
    add_column :evangelism_meetings, :active, :boolean, null: false, default: true
    add_column :evangelism_meetings, :display_order, :integer

    add_index :evangelism_meetings, :active
    add_index :evangelism_meetings, :display_order
  end
end
