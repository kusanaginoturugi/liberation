class CreateEventDetails < ActiveRecord::Migration[8.0]
  def change
    create_table :event_details do |t|
      t.references :event, null: false, foreign_key: true
      t.references :region, null: false, foreign_key: true, default: 1
      t.integer :count, null: false, default: 0

      t.timestamps
    end

    add_index :event_details, [:event_id, :region_id], unique: true
  end
end
