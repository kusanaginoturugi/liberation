class CreateCeremonySchedules < ActiveRecord::Migration[8.0]
  def change
    create_table :ceremony_schedules do |t|
      t.references :fellowship, null: false, foreign_key: true
      t.datetime :ceremony_at, null: false
      t.string :place, null: false
      t.integer :assistant_count, null: false
      t.integer :spirit_count, null: false
      t.string :minister_name, null: false

      t.timestamps
    end

    add_index :ceremony_schedules, :ceremony_at
  end
end
