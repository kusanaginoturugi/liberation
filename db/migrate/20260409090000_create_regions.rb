class CreateRegions < ActiveRecord::Migration[8.0]
  def change
    create_table :regions do |t|
      t.text :name, null: false

      t.timestamps
    end

    add_index :regions, :name, unique: true
  end
end
