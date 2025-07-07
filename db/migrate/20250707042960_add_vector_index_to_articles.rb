class AddVectorIndexToArticles < ActiveRecord::Migration[8.0]
  def change
    # Change embedding column from text to vector type with proper casting
    execute "ALTER TABLE articles ALTER COLUMN embedding TYPE vector(1536) USING embedding::vector"
    
    # Add vector similarity index for embedding search
    add_index :articles, :embedding, using: :ivfflat, opclass: :vector_cosine_ops, 
              name: 'index_articles_on_embedding_cosine'
    
    # Add additional performance indexes
    add_index :articles, [:is_active, :regulation_id], name: 'index_articles_on_active_regulation'
    add_index :articles, :created_at, name: 'index_articles_on_created_at'
    add_index :articles, :updated_at, name: 'index_articles_on_updated_at'
  end
end
