# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Api::SearchController, type: :request do
  let(:regulation) { create(:regulation) }
  let!(:articles) do
    3.times.map do |i|
      create(:article, 
             regulation: regulation, 
             embedding: Array.new(1536, 0.1 + i * 0.1),
             is_active: true)
    end
  end

  before do
    # OpenAI API 스텁
    stub_openai_embeddings_api
    stub_openai_chat_completions_api
  end

  describe 'POST /api/search/rag' do
    let(:valid_params) do
      {
        query: "대학교 등록금 납부 기한은 언제인가요?",
        model: "gpt-4",
        response_format: "detailed"
      }
    end

    it 'returns successful RAG answer' do
      post '/api/search/rag', params: valid_params

      expect(response).to have_http_status(:ok)
      
      json_response = JSON.parse(response.body)
      expect(json_response['success']).to be true
      expect(json_response['query']).to eq(valid_params[:query])
      expect(json_response['answer']).to be_present
      expect(json_response['sources']).to be_an(Array)
      expect(json_response['metadata']).to be_present
      expect(json_response['cached']).to be false
    end

    it 'returns cached result on second request' do
      # First request
      post '/api/search/rag', params: valid_params
      expect(response).to have_http_status(:ok)
      
      first_response = JSON.parse(response.body)
      expect(first_response['cached']).to be false

      # Second request (should be cached)
      post '/api/search/rag', params: valid_params
      expect(response).to have_http_status(:ok)
      
      second_response = JSON.parse(response.body)
      expect(second_response['cached']).to be true
      expect(second_response['cache_key']).to be_present
    end

    it 'returns 404 when no search results found' do
      # Create articles without embeddings
      Article.update_all(embedding: nil)
      
      post '/api/search/rag', params: valid_params

      expect(response).to have_http_status(:not_found)
      
      json_response = JSON.parse(response.body)
      expect(json_response['success']).to be false
      expect(json_response['error']).to include('검색 결과가 없습니다')
    end

    it 'validates required parameters' do
      post '/api/search/rag', params: { query: '' }

      expect(response).to have_http_status(:bad_request)
    end

    it 'handles different response formats' do
      %w[brief detailed structured].each do |format|
        post '/api/search/rag', params: valid_params.merge(response_format: format)
        
        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['metadata']['response_format']).to eq(format)
      end
    end

    it 'handles different GPT models' do
      %w[gpt-4 gpt-3.5-turbo].each do |model|
        post '/api/search/rag', params: valid_params.merge(model: model)
        
        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response['metadata']['model_used']).to eq(model)
      end
    end

    it 'handles OpenAI API errors gracefully' do
      stub_openai_chat_completions_api_error(status: 429, message: 'Rate limit exceeded')
      
      post '/api/search/rag', params: valid_params

      expect(response).to have_http_status(:bad_gateway)
      
      json_response = JSON.parse(response.body)
      expect(json_response['success']).to be false
      expect(json_response['error']).to be_present
    end
  end

  describe 'POST /api/search/ab_test' do
    let(:valid_params) do
      {
        query: "대학교 등록금 납부 기한은 언제인가요?"
      }
    end

    it 'returns A/B test variants' do
      post '/api/search/ab_test', params: valid_params

      expect(response).to have_http_status(:ok)
      
      json_response = JSON.parse(response.body)
      expect(json_response['success']).to be true
      expect(json_response['variant_a']).to be_present
      expect(json_response['variant_b']).to be_present
      expect(json_response['test_metadata']).to be_present
      expect(json_response['test_metadata']['test_id']).to be_present
    end

    it 'returns different variants with different settings' do
      post '/api/search/ab_test', params: valid_params

      expect(response).to have_http_status(:ok)
      
      json_response = JSON.parse(response.body)
      variant_a = json_response['variant_a']
      variant_b = json_response['variant_b']
      
      # Variants should have different metadata (temperature, format)
      expect(variant_a['metadata']['temperature']).not_to eq(variant_b['metadata']['temperature'])
    end
  end

  describe 'GET /api/search/stats' do
    before do
      # Create some search query logs
      create_list(:search_query, 5, :recent)
      create_list(:search_query, 3, :old)
    end

    it 'returns search statistics' do
      get '/api/search/stats'

      expect(response).to have_http_status(:ok)
      
      json_response = JSON.parse(response.body)
      expect(json_response['success']).to be true
      expect(json_response['stats']).to be_present
      expect(json_response['stats']['total_searches']).to eq(8)
      expect(json_response['stats']['recent_searches']).to eq(5)
      expect(json_response['stats']['popular_queries']).to be_an(Array)
      expect(json_response['stats']['system_health']).to be_present
    end
  end

  describe 'GET /api/health' do
    it 'returns system health status' do
      get '/api/health'

      expect(response).to have_http_status(:ok)
      
      json_response = JSON.parse(response.body)
      expect(json_response['status']).to be_in(['healthy', 'degraded'])
      expect(json_response['services']).to be_present
      expect(json_response['services']['database']).to be_present
      expect(json_response['services']['redis']).to be_present
      expect(json_response['services']['pgvector']).to be_present
    end

    it 'checks individual service health' do
      get '/api/health'

      json_response = JSON.parse(response.body)
      services = json_response['services']
      
      expect(services['database']['status']).to eq('healthy')
      expect(services['redis']['status']).to eq('healthy')
      expect(services['pgvector']['status']).to eq('healthy')
    end
  end

  describe 'Rate limiting' do
    it 'enforces rate limits' do
      # Stub rate limit to 2 requests per hour for testing
      allow_any_instance_of(Api::SearchController).to receive(:rate_limit_per_hour).and_return(2)
      
      # First two requests should succeed
      2.times do
        post '/api/search/rag', params: { query: "test query #{rand}" }
        expect(response).to have_http_status(:ok)
      end
      
      # Third request should be rate limited
      post '/api/search/rag', params: { query: "test query rate limited" }
      expect(response).to have_http_status(:too_many_requests)
      
      json_response = JSON.parse(response.body)
      expect(json_response['error']).to include('Rate limit exceeded')
    end
  end

  describe 'Error handling' do
    it 'handles invalid JSON gracefully' do
      post '/api/search/rag', 
           params: "invalid json", 
           headers: { 'Content-Type' => 'application/json' }

      expect(response).to have_http_status(:bad_request)
    end

    it 'handles missing parameters' do
      post '/api/search/rag', params: {}

      expect(response).to have_http_status(:bad_request)
    end

    it 'handles database connection errors' do
      allow(ActiveRecord::Base).to receive(:connection).and_raise(ActiveRecord::ConnectionNotEstablished)
      
      get '/api/health'
      
      json_response = JSON.parse(response.body)
      expect(json_response['services']['database']['status']).to eq('unhealthy')
    end
  end

  describe 'Logging and monitoring' do
    it 'logs API requests' do
      expect(Rails.logger).to receive(:info).with(/API Request/)
      expect(Rails.logger).to receive(:info).with(/Params/)
      expect(Rails.logger).to receive(:info).with(/IP/)
      
      post '/api/search/rag', params: { query: "test query" }
    end

    it 'creates SearchQuery logs for successful requests' do
      expect {
        post '/api/search/rag', params: { query: "test query for logging" }
      }.to change(SearchQuery, :count).by(1)
      
      search_query = SearchQuery.last
      expect(search_query.query_text).to eq("test query for logging")
      expect(search_query.results_count).to be > 0
      expect(search_query.response_time_ms).to be > 0
    end
  end
end