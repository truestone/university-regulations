# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SearchQuery, type: :model do
  let(:valid_attributes) do
    {
      query_text: "대학교 등록금 납부 기한은 언제인가요?",
      embedding: Array.new(1536, 0.1),
      results_count: 5,
      response_time_ms: 150,
      metadata: { question_type: 'when', complexity: 'medium' }
    }
  end

  describe 'validations' do
    it 'validates presence of query_text' do
      search_query = SearchQuery.new(valid_attributes.except(:query_text))
      expect(search_query).not_to be_valid
      expect(search_query.errors[:query_text]).to include("can't be blank")
    end

    it 'validates presence of embedding' do
      search_query = SearchQuery.new(valid_attributes.except(:embedding))
      expect(search_query).not_to be_valid
      expect(search_query.errors[:embedding]).to include("can't be blank")
    end

    it 'validates embedding dimensions' do
      search_query = SearchQuery.new(valid_attributes.merge(embedding: Array.new(100, 0.1)))
      expect(search_query).not_to be_valid
      expect(search_query.errors[:embedding]).to include('must be a 1536-dimensional vector')
    end

    it 'validates presence and positivity of response_time_ms' do
      search_query = SearchQuery.new(valid_attributes.merge(response_time_ms: -1))
      expect(search_query).not_to be_valid
      expect(search_query.errors[:response_time_ms]).to include('must be greater than 0')
    end
  end

  describe 'scopes' do
    let!(:recent_query) { create(:search_query, created_at: 1.day.ago) }
    let!(:old_query) { create(:search_query, created_at: 2.weeks.ago) }
    let!(:successful_query) { create(:search_query, error_message: nil) }
    let!(:failed_query) { create(:search_query, error_message: 'API Error') }

    describe '.recent' do
      it 'returns queries from the last week' do
        expect(SearchQuery.recent).to include(recent_query)
        expect(SearchQuery.recent).not_to include(old_query)
      end
    end

    describe '.successful' do
      it 'returns queries without error messages' do
        expect(SearchQuery.successful).to include(successful_query)
        expect(SearchQuery.successful).not_to include(failed_query)
      end
    end

    describe '.failed' do
      it 'returns queries with error messages' do
        expect(SearchQuery.failed).to include(failed_query)
        expect(SearchQuery.failed).not_to include(successful_query)
      end
    end
  end

  describe '.log_search' do
    it 'creates a search query log' do
      expect {
        SearchQuery.log_search(
          query_text: "테스트 질문",
          embedding: Array.new(1536, 0.1),
          results_count: 3,
          response_time_ms: 200,
          metadata: { test: true }
        )
      }.to change(SearchQuery, :count).by(1)
    end

    it 'handles logging errors gracefully' do
      expect {
        SearchQuery.log_search(
          query_text: nil, # Invalid data
          embedding: Array.new(1536, 0.1),
          results_count: 3,
          response_time_ms: 200
        )
      }.not_to raise_error
    end
  end

  describe '#similar_queries' do
    let!(:query1) { create(:search_query, embedding: Array.new(1536, 0.1)) }
    let!(:query2) { create(:search_query, embedding: Array.new(1536, 0.2)) }
    let!(:query3) { create(:search_query, embedding: Array.new(1536, 0.1)) }

    it 'finds similar queries based on embedding distance' do
      similar = query1.similar_queries
      expect(similar).to include(query3)
      expect(similar).not_to include(query1) # Excludes self
    end

    it 'respects the limit parameter' do
      similar = query1.similar_queries(limit: 1)
      expect(similar.count).to eq(1)
    end
  end

  describe '.performance_stats' do
    before do
      # Create test data
      create(:search_query, error_message: nil, response_time_ms: 100, results_count: 5, created_at: 1.day.ago)
      create(:search_query, error_message: nil, response_time_ms: 200, results_count: 3, created_at: 2.days.ago)
      create(:search_query, error_message: 'API Error', response_time_ms: 500, results_count: 0, created_at: 3.days.ago)
      create(:search_query, created_at: 2.weeks.ago) # Outside period
    end

    it 'calculates performance statistics' do
      stats = SearchQuery.performance_stats(period: 1.week)
      
      expect(stats[:total_queries]).to eq(3)
      expect(stats[:successful_queries]).to eq(2)
      expect(stats[:failed_queries]).to eq(1)
      expect(stats[:avg_response_time]).to be_present
      expect(stats[:avg_results_count]).to be_present
      expect(stats[:most_common_errors]).to be_an(Array)
    end
  end

  describe '.popular_queries' do
    before do
      create(:search_query, query_text: "등록금 납부", created_at: 1.day.ago)
      create(:search_query, query_text: "등록금 납부", created_at: 2.days.ago)
      create(:search_query, query_text: "휴학 신청", created_at: 3.days.ago)
      create(:search_query, query_text: "오래된 질문", created_at: 2.weeks.ago)
    end

    it 'returns popular queries within the specified period' do
      popular = SearchQuery.popular_queries(limit: 5, period: 1.week)
      
      expect(popular).to be_an(Array)
      expect(popular.first[:query]).to eq("등록금 납부")
      expect(popular.first[:count]).to eq(2)
    end

    it 'respects the limit parameter' do
      popular = SearchQuery.popular_queries(limit: 1)
      expect(popular.length).to eq(1)
    end
  end
end