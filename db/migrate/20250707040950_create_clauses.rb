class CreateClauses < ActiveRecord::Migration[8.0]
  def change
    create_table :clauses do |t|
      t.references :article, null: false, foreign_key: true
      t.integer :number, null: false
      t.text :content, null: false
      t.string :clause_type, default: 'paragraph'
      t.integer :sort_order, null: false
      t.boolean :is_active, default: true, null: false

      t.timestamps
    end
    
    add_index :clauses, [:article_id, :number], unique: true
    add_index :clauses, [:article_id, :sort_order]
    add_index :clauses, :clause_type
  end
end
