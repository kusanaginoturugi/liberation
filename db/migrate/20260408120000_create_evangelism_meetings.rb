class CreateEvangelismMeetings < ActiveRecord::Migration[8.0]
  def change
    create_table :evangelism_meetings do |t|
      t.string :name, null: false
      t.string :color_code, null: false

      t.timestamps
    end

    add_index :evangelism_meetings, :name, unique: true
  end
end
