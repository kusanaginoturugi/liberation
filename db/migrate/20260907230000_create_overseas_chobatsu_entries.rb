class CreateOverseasChobatsuEntries < ActiveRecord::Migration[8.1]
  def change
    create_table :overseas_chobatsu_entries do |t|
      t.references :event, null: false, foreign_key: true
      t.references :fellowship, null: false, foreign_key: true
      t.string :assistant_name
      t.integer :spirit_count
      t.text :notes

      t.timestamps
    end

    add_index :overseas_chobatsu_entries, [ :event_id, :fellowship_id ], unique: true,
      name: "idx_overseas_entries_event_fellowship"
  end
end
