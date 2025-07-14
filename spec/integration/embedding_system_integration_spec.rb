# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Embedding System Integration', type: :integration do
  let(:regulation) { create(:regulation) }
  let!(:articles) { create_list(:article, 3, regulation: regulation) }

  describe 'End-to-end embedding workflow', :sidekiq_inline do
    it 'automatically generates embeddings when articles are created' do
      # Create a new article
      new_article = create(:article, regulation: regulation, content: 'New article content')
      
      # Check that embedding was generated
      new_article.reload
      expect(new_article.embedding).to be_present
      expect(new_article.embedding.length).to eq(1536)
      expect(new_article.embedding_updated_at).to be_present
    end

    it 'regenerates embeddings when articles are updated' do
      article = articles.first
      
      # Initially no embedding
      expect(article.embedding).to be_nil
      
      # Update the article
      article.update!(content: 'Updated content')
      
      # Check that embedding was generated
      article.reload
      expect(article.embedding).to be_present
      expect(article.embedding_updated_at).to be_present
    end

    it 'skips embedding generation when not needed' do
      article = articles.first
      
      # Set up existing embedding
      article.update_columns(
        embedding: Array.new(1536, 0.2),
        embedding_updated_at: 1.hour.from_now
      )
      
      original_embedding = article.embedding
      original_updated_at = article.embedding_updated_at
      
      # Update only title (not content)
      article.update_column(:updated_at, 2.hours.ago)
      article.update!(title: 'New title only')
      
      # Embedding should not change
      article.reload
      expect(article.embedding).to eq(original_embedding)
      expect(article.embedding_updated_at).to eq(original_updated_at)
    end
  end

  describe 'Rake tasks integration', :sidekiq_fake do
    before do
      # Clear any existing jobs
      Sidekiq::Worker.clear_all
    end

    it 'embedding:generate_all enqueues jobs for all articles' do
      expect {
        Rake::Task['embedding:generate_all'].invoke
      }.to change(EmbeddingJob.jobs, :size).by(3)
    end

    it 'embedding:generate_missing only enqueues jobs for articles without embeddings' do
      # Give one article an embedding
      articles.first.update_columns(embedding: Array.new(1536, 0.1))
      
      expect {
        Rake::Task['embedding:generate_missing'].invoke
      }.to change(EmbeddingJob.jobs, :size).by(2)
    end

    it 'embedding:update_modified only enqueues jobs for recently modified articles' do
      # Set up articles with embeddings
      articles.each do |article|
        article.update_columns(
          embedding: Array.new(1536, 0.1),
          embedding_updated_at: 2.hours.ago
        )
      end
      
      # Make one article recently modified
      articles.first.update_columns(updated_at: 30.minutes.ago)
      
      expect {
        Rake::Task['embedding:update_modified'].invoke
      }.to change(EmbeddingJob.jobs, :size).by(1)
    end
  end

  describe 'Error handling and resilience' do
    it 'handles OpenAI API errors gracefully', :sidekiq_inline do
      # Stub API to return error
      stub_openai_embeddings_api_error(status: 429, message: 'Rate limit exceeded')
      
      article = articles.first
      
      expect {
        article.update!(content: 'New content')
      }.to raise_error(StandardError, /Rate limit exceeded/)
      
      # Article should still be updated, just without embedding
      article.reload
      expect(article.content).to eq('New content')
      expect(article.embedding).to be_nil
    end

    it 'retries failed jobs according to Sidekiq configuration' do
      # This test would require more complex setup to test actual retries
      # For now, we just verify the job configuration
      expect(EmbeddingJob.sidekiq_options['retry']).to eq(5)
      expect(EmbeddingJob.sidekiq_options['queue']).to eq('embedding')
    end
  end

  describe 'Performance and batching' do
    let!(:many_articles) { create_list(:article, 25, regulation: regulation) }

    it 'processes articles in batches to avoid memory issues', :sidekiq_fake do
      expect {
        Rake::Task['embedding:generate_all'].invoke
      }.to change(EmbeddingJob.jobs, :size).by(28) # 3 original + 25 new
      
      # Verify batch processing doesn't cause memory issues
      # (This is more of a smoke test)
      expect(Article.count).to eq(28)
    end
  end

  describe 'Database constraints and validations' do
    it 'validates embedding vector dimensions' do
      article = articles.first
      
      # Try to set invalid embedding
      expect {
        article.update!(embedding: Array.new(100, 0.1))
      }.to raise_error(ActiveRecord::RecordInvalid, /must be a 1536-dimensional vector/)
    end

    it 'allows nil embeddings' do
      article = articles.first
      expect {
        article.update!(embedding: nil)
      }.not_to raise_error
    end
  end
end