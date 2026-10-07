class CreateCeremonyScheduleFellowships < ActiveRecord::Migration[8.1]
  def change
    create_table :ceremony_schedule_fellowships do |t|
      t.references :ceremony_schedule, null: false, foreign_key: true
      t.references :fellowship, null: false, foreign_key: true
      t.integer :spirit_count, null: false

      t.timestamps
    end

    add_index :ceremony_schedule_fellowships, [ :ceremony_schedule_id, :fellowship_id ], unique: true,
              name: "idx_schedule_fellowships_schedule_fellowship"
    add_column :ceremony_schedules, :joint_schedule, :boolean, null: false, default: false
  end
end
