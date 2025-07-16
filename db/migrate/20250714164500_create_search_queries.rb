# frozen_string_literal: true

class CreateSearchQueries < ActiveRecord::Migration[8.0]
  def change
    create_table :search_queries do |t|
      t.text :query_text, null: false
      t.column :embedding, 'vector(1536)', null: false
      t.integer :results_count, null: false, default: 0
      t.integer :response_time_ms, null: false
      t.jsonb :metadata, default: {}
      t.text :error_message
      t.inet :ip_address
      t.string :user_agent
      t.string :session_id

      t.timestamps
    end

    # 인덱스 추가
    add_index :search_queries, :query_text
    add_index :search_queries, :created_at
    add_index :search_queries, :results_count
    add_index :search_queries, :response_time_ms
    add_index :search_queries, :metadata, using: :gin
    
    # pgvector 인덱스 (HNSW)
    add_index :search_queries, :embedding, using: :hnsw, opclass: :vector_cosine_ops
  end
end