class CreateMessages < ActiveRecord::Migration[8.0]
  def change
    create_table :messages do |t|
      t.references :conversation, null: false, foreign_key: true
      t.string :role, null: false
      t.text :content, null: false
      t.integer :tokens_used, default: 0

      t.timestamps
    end
    
    add_index :messages, [:conversation_id, :created_at]
    add_index :messages, :role
  end
end
