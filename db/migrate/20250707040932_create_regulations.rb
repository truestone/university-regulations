class CreateRegulations < ActiveRecord::Migration[8.0]
  def change
    create_table :regulations do |t|
      t.references :chapter, null: false, foreign_key: true
      t.integer :number, null: false
      t.string :title, null: false
      t.text :content
      t.string :regulation_code, null: false
      t.string :status, default: 'active'
      t.integer :sort_order, null: false
      t.boolean :is_active, default: true, null: false

      t.timestamps
    end
    
    add_index :regulations, :regulation_code, unique: true
    add_index :regulations, [:chapter_id, :number], unique: true
    add_index :regulations, [:chapter_id, :sort_order]
    add_index :regulations, :status
  end
end
