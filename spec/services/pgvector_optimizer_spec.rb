# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PgvectorOptimizer, type: :service do
  let(:sample_embedding) { Array.new(1536, 0.1) }
  let(:optimizer) { described_class.new(embedding: sample_embedding) }

  describe 'validations' do
    it 'validates presence of embedding' do
      optimizer = described_class.new(embedding: nil)
      expect(optimizer).not_to be_valid
      expect(optimizer.errors[:embedding]).to include("can't be blank")
    end

    it 'validates limit range' do
      optimizer = described_class.new(embedding: sample_embedding, limit: 0)
      expect(optimizer).not_to be_valid
      expect(optimizer.errors[:limit]).to include('must be greater than 0')

      optimizer = described_class.new(embedding: sample_embedding, limit: 101)
      expect(optimizer).not_to be_valid
      expect(optimizer.errors[:limit]).to include('must be less than or equal to 100')
    end

    it 'validates similarity_threshold range' do
      optimizer = described_class.new(embedding: sample_embedding, similarity_threshold: 0)
      expect(optimizer).not_to be_valid

      optimizer = described_class.new(embedding: sample_embedding, similarity_threshold: 1.1)
      expect(optimizer).not_to be_valid
    end

    it 'validates distance_function inclusion' do
      optimizer = described_class.new(embedding: sample_embedding, distance_function: 'invalid')
      expect(optimizer).not_to be_valid
      expect(optimizer.errors[:distance_function]).to include('is not included in the list')
    end
  end

  describe '.search' do
    let(:regulation) { create(:regulation) }
    let!(:articles) do
      3.times.map do |i|
        create(:article, 
               regulation: regulation, 
               embedding: Array.new(1536, 0.1 + i * 0.1),
               is_active: true)
      end
    end

    it 'returns search results' do
      results = described_class.search(
        embedding: sample_embedding,
        limit: 5,
        similarity_threshold: 0.5
      )

      expect(results).to be_an(Array)
      expect(results.length).to be <= 5
      
      if results.any?
        result = results.first
        expect(result).to have_key(:id)
        expect(result).to have_key(:title)
        expect(result).to have_key(:content)
        expect(result).to have_key(:distance)
        expect(result).to have_key(:similarity)
      end
    end

    it 'respects similarity threshold' do
      results = described_class.search(
        embedding: sample_embedding,
        limit: 10,
        similarity_threshold: 0.9  # Very high threshold
      )

      results.each do |result|
        expect(result[:similarity]).to be >= 0.9
      end
    end

    it 'limits results correctly' do
      results = described_class.search(
        embedding: sample_embedding,
        limit: 2
      )

      expect(results.length).to be <= 2
    end
  end

  describe '#execute_search' do
    let(:regulation) { create(:regulation) }
    let!(:article) { create(:article, regulation: regulation, embedding: sample_embedding, is_active: true) }

    it 'executes search successfully' do
      results = optimizer.execute_search

      expect(results).to be_an(Array)
      if results.any?
        expect(results.first).to have_key(:id)
        expect(results.first).to have_key(:distance)
      end
    end

    it 'handles search errors gracefully' do
      # Invalid embedding to trigger error
      optimizer = described_class.new(embedding: 'invalid')
      
      expect {
        optimizer.execute_search
      }.to raise_error
    end
  end

  describe '#analyze_query_performance' do
    let(:regulation) { create(:regulation) }
    let!(:article) { create(:article, regulation: regulation, embedding: sample_embedding, is_active: true) }

    it 'analyzes query performance' do
      analysis = optimizer.analyze_query_performance

      expect(analysis).to be_a(Hash)
      expect(analysis).to have_key(:execution_time)
      expect(analysis).to have_key(:planning_time)
      expect(analysis).to have_key(:rows_returned)
    end
  end

  describe 'distance functions' do
    let(:regulation) { create(:regulation) }
    let!(:article) { create(:article, regulation: regulation, embedding: sample_embedding, is_active: true) }

    it 'works with cosine distance' do
      optimizer = described_class.new(embedding: sample_embedding, distance_function: 'cosine')
      results = optimizer.execute_search
      expect(results).to be_an(Array)
    end

    it 'works with L2 distance' do
      optimizer = described_class.new(embedding: sample_embedding, distance_function: 'l2')
      results = optimizer.execute_search
      expect(results).to be_an(Array)
    end

    it 'works with inner product' do
      optimizer = described_class.new(embedding: sample_embedding, distance_function: 'inner_product')
      results = optimizer.execute_search
      expect(results).to be_an(Array)
    end
  end

  describe '.recommend_parameters' do
    it 'recommends parameters for small datasets' do
      params = described_class.recommend_parameters(article_count: 500)
      
      expect(params[:distance_function]).to eq('cosine')
      expect(params[:use_ivfflat]).to be false
      expect(params[:ef_search]).to eq(40)
    end

    it 'recommends parameters for medium datasets' do
      params = described_class.recommend_parameters(article_count: 5000)
      
      expect(params[:distance_function]).to eq('cosine')
      expect(params[:ef_search]).to be <= 40
    end

    it 'recommends parameters for large datasets' do
      params = described_class.recommend_parameters(article_count: 50000)
      
      expect(params[:distance_function]).to eq('cosine')
      expect(params[:use_ivfflat]).to be true
      expect(params[:ef_search]).to be <= 32
    end

    it 'adjusts for high query frequency' do
      params = described_class.recommend_parameters(
        article_count: 10000, 
        query_frequency: :high
      )
      
      expect(params[:ef_search]).to be < 40  # Lower ef_search for high frequency
    end
  end

  describe 'performance logging' do
    it 'logs performance metrics' do
      expect(Rails.logger).to receive(:info).with(/PgvectorOptimizer Performance/)
      
      optimizer.send(:log_performance_metrics, 5, 150.0, 'SELECT * FROM articles')
    end

    it 'stores performance metrics in cache' do
      expect(Rails.cache).to receive(:write).with(
        anything,
        hash_including(:result_count, :execution_time),
        expires_in: 24.hours
      )
      
      optimizer.send(:store_performance_metrics, 5, 150.0)
    end
  end
end