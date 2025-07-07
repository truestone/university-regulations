class CreateEditions < ActiveRecord::Migration[8.0]
  def change
    create_table :editions do |t|
      t.integer :number, null: false
      t.string :title, null: false
      t.text :description
      t.integer :sort_order, null: false
      t.boolean :is_active, default: true, null: false

      t.timestamps
    end
    
    add_index :editions, :number, unique: true
    add_index :editions, :sort_order
  end
end
