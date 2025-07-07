class ImproveIndexesAndConstraints < ActiveRecord::Migration[8.0]
  def change
    # Add performance indexes for common query patterns
    add_index :users, :role, name: 'index_users_on_role'
    add_index :users, :last_login_at, name: 'index_users_on_last_login_at'
    
    # Add composite indexes for hierarchical queries
    add_index :chapters, [:is_active, :edition_id], name: 'index_chapters_on_active_edition'
    add_index :regulations, [:is_active, :chapter_id], name: 'index_regulations_on_active_chapter'
    add_index :regulations, [:status, :chapter_id], name: 'index_regulations_on_status_chapter'
    add_index :clauses, [:is_active, :article_id], name: 'index_clauses_on_active_article'
    
    # Add indexes for AI conversation system
    add_index :conversations, [:expires_at, :last_message_at], name: 'index_conversations_on_expires_last_message'
    add_index :messages, [:role, :conversation_id], name: 'index_messages_on_role_conversation'
    add_index :messages, :tokens_used, name: 'index_messages_on_tokens_used'
    
    # Add indexes for AI settings
    add_index :ai_settings, [:is_active, :provider], name: 'index_ai_settings_on_active_provider'
    add_index :ai_settings, :usage_this_month, name: 'index_ai_settings_on_usage'
    add_index :ai_settings, :last_used_at, name: 'index_ai_settings_on_last_used'
    
    # Full-text search indexes will be added after pg_trgm extension is enabled
    # add_index :regulations, :title, using: :gin, opclass: :gin_trgm_ops, name: 'index_regulations_on_title_gin'
    # add_index :articles, :title, using: :gin, opclass: :gin_trgm_ops, name: 'index_articles_on_title_gin'
    # add_index :articles, :content, using: :gin, opclass: :gin_trgm_ops, name: 'index_articles_on_content_gin'
  end
end
