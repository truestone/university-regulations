class CreateChapters < ActiveRecord::Migration[8.0]
  def change
    create_table :chapters do |t|
      t.references :edition, null: false, foreign_key: true
      t.integer :number, null: false
      t.string :title, null: false
      t.text :description
      t.integer :sort_order, null: false
      t.boolean :is_active, default: true, null: false

      t.timestamps
    end
    
    add_index :chapters, [:edition_id, :number], unique: true
    add_index :chapters, [:edition_id, :sort_order]
  end
end
