class AddLoginIdToUsers < ActiveRecord::Migration[8.0]
  def up
    add_column :users, :login_id, :string

    execute <<~SQL.squish
      UPDATE users
      SET login_id = CAST(id AS TEXT)
      WHERE login_id IS NULL
    SQL

    change_column_null :users, :login_id, false
    add_index :users, :login_id, unique: true
  end

  def down
    remove_index :users, :login_id
    remove_column :users, :login_id
  end
end
