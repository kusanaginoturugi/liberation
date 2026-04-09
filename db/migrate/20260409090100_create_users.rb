class CreateUsers < ActiveRecord::Migration[8.0]
  def change
    create_table :users do |t|
      t.text :email, null: false
      t.string :password_digest, null: false
      t.text :name, null: false
      t.references :region, null: false, foreign_key: true

      t.timestamps
    end

    add_index :users, :email, unique: true
  end
end
