class CreateArticles < ActiveRecord::Migration[8.0]
  def change
    create_table :articles do |t|
      t.references :regulation, null: false, foreign_key: true
      t.integer :number
      t.string :title
      t.text :content
      t.integer :sort_order
      t.boolean :is_active, default: true
      t.text :embedding

      t.timestamps
    end
    
    add_index :articles, [:regulation_id, :sort_order]
    # Vector index will be added later when pgvector gem is properly configured
    # add_index :articles, :embedding, using: :ivfflat, opclass: :vector_cosine_ops
  end
end
