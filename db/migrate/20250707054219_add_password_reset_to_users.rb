class AddPasswordResetToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :password_reset_token, :string
    add_column :users, :password_reset_sent_at, :datetime
    add_column :users, :failed_attempts, :integer, default: 0
    add_column :users, :locked_until, :datetime
    
    add_index :users, :password_reset_token, unique: true
    add_index :users, :failed_attempts
    add_index :users, :locked_until
  end
end
