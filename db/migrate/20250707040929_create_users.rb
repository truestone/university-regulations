class CreateUsers < ActiveRecord::Migration[8.0]
  def change
    create_table :users do |t|
      t.string :email
      t.string :password_digest
      t.string :name
      t.string :role
      t.datetime :last_login_at

      t.timestamps
    end
    add_index :users, :email, unique: true
  end
end
