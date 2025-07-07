class CreateConversations < ActiveRecord::Migration[8.0]
  def change
    create_table :conversations do |t|
      t.string :session_id, null: false
      t.string :title
      t.datetime :last_message_at
      t.datetime :expires_at, null: false

      t.timestamps
    end
    
    add_index :conversations, :session_id, unique: true
    add_index :conversations, :expires_at
    add_index :conversations, :last_message_at
  end
end
