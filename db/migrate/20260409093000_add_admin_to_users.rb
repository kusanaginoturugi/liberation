class AddAdminToUsers < ActiveRecord::Migration[8.0]
  def up
    add_column :users, :admin, :boolean, null: false, default: false

    execute <<~SQL
      UPDATE users
      SET admin = 1
      WHERE email = 'admin@example.com'
    SQL
  end

  def down
    remove_column :users, :admin
  end
end
