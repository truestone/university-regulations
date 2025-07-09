# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Database Indexes', type: :model do
  describe 'PostgreSQL extensions' do
    it 'has pgvector extension enabled' do
      expect(extension_enabled?('vector')).to be true
    end

    it 'has pg_trgm extension enabled' do
      expect(extension_enabled?('pg_trgm')).to be true
    end
  end

  describe 'Primary key indexes' do
    %w[users editions chapters regulations articles clauses conversations messages ai_settings].each do |table|
      it "has primary key index on #{table}" do
        expect(index_exists?(table, 'id')).to be true
      end
    end
  end

  describe 'Foreign key indexes' do
    it 'has foreign key indexes for chapters' do
      expect(index_exists?('chapters', 'edition_id')).to be true
    end

    it 'has foreign key indexes for regulations' do
      expect(index_exists?('regulations', 'chapter_id')).to be true
    end

    it 'has foreign key indexes for articles' do
      expect(index_exists?('articles', 'regulation_id')).to be true
    end

    it 'has foreign key indexes for clauses' do
      expect(index_exists?('clauses', 'article_id')).to be true
    end

    it 'has foreign key indexes for conversations' do
      expect(index_exists?('conversations', 'user_id')).to be true
    end

    it 'has foreign key indexes for messages' do
      expect(index_exists?('messages', 'conversation_id')).to be true
    end
  end

  describe 'Performance optimization indexes' do
    it 'has composite index for edition hierarchy' do
      expect(index_exists?('editions', %w[sort_order status])).to be true
    end

    it 'has composite index for chapter hierarchy' do
      expect(index_exists?('chapters', %w[edition_id sort_order])).to be true
    end

    it 'has composite index for regulation hierarchy' do
      expect(index_exists?('regulations', %w[chapter_id sort_order])).to be true
    end

    it 'has composite index for article hierarchy' do
      expect(index_exists?('articles', %w[regulation_id sort_order])).to be true
    end

    it 'has composite index for clause hierarchy' do
      expect(index_exists?('clauses', %w[article_id sort_order])).to be true
    end
  end

  describe 'Vector similarity indexes' do
    it 'has vector index on articles embedding column' do
      expect(vector_index_exists?('articles', 'embedding')).to be true
    end
  end

  describe 'Unique constraint indexes' do
    it 'has unique index on users email' do
      expect(index_exists?('users', 'email')).to be true
    end

    it 'has unique index on regulation codes' do
      expect(index_exists?('regulations', 'regulation_code')).to be true
    end
  end

  describe 'Search optimization indexes' do
    it 'has index on user role for authorization' do
      expect(index_exists?('users', 'role')).to be true
    end

    it 'has index on ai_settings provider' do
      expect(index_exists?('ai_settings', 'provider')).to be true
    end

    it 'has index on ai_settings active status' do
      expect(index_exists?('ai_settings', 'is_active')).to be true
    end
  end

  describe 'Timestamp indexes' do
    %w[users editions chapters regulations articles clauses conversations messages ai_settings].each do |table|
      it "has created_at index on #{table}" do
        expect(index_exists?(table, 'created_at')).to be true
      end

      it "has updated_at index on #{table}" do
        expect(index_exists?(table, 'updated_at')).to be true
      end
    end
  end
end