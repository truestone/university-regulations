# frozen_string_literal: true

require 'rails_helper'
require 'benchmark/ips'
require 'memory_profiler'

RSpec.describe 'API Performance Tests', type: :request do
  let(:regulation) { create(:regulation) }
  let!(:articles) do
    10.times.map do |i|
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

  describe 'RAG Search Performance' do
    let(:search_params) do
      {
        question: "학사 규정에 대해 알려주세요",
        format: "detailed"
      }
    end

    it 'responds within 300ms average' do
      response_times = []
      
      10.times do
        start_time = Time.current
        post '/api/search/rag', params: search_params, as: :json
        end_time = Time.current
        
        expect(response).to have_http_status(:success)
        response_times << (end_time - start_time) * 1000 # Convert to ms
      end
      
      average_time = response_times.sum / response_times.size
      expect(average_time).to be < 300, "Average response time #{average_time}ms exceeds 300ms limit"
      
      puts "Average response time: #{average_time.round(2)}ms"
      puts "Min: #{response_times.min.round(2)}ms, Max: #{response_times.max.round(2)}ms"
    end

    it 'handles concurrent requests efficiently' do
      threads = []
      response_times = []
      mutex = Mutex.new
      
      5.times do
        threads << Thread.new do
          start_time = Time.current
          post '/api/search/rag', params: search_params, as: :json
          end_time = Time.current
          
          mutex.synchronize do
            response_times << (end_time - start_time) * 1000
          end
        end
      end
      
      threads.each(&:join)
      
      average_time = response_times.sum / response_times.size
      expect(average_time).to be < 500, "Concurrent average response time #{average_time}ms exceeds 500ms limit"
      
      puts "Concurrent average response time: #{average_time.round(2)}ms"
    end

    it 'uses acceptable memory for search operations' do
      report = MemoryProfiler.report do
        5.times do
          post '/api/search/rag', params: search_params, as: :json
        end
      end
      
      # Memory usage should be reasonable (less than 50MB for 5 requests)
      total_allocated = report.total_allocated_memsize
      expect(total_allocated).to be < 50.megabytes, 
        "Memory usage #{total_allocated / 1.megabyte}MB exceeds 50MB limit"
      
      puts "Total allocated memory: #{(total_allocated / 1.megabyte).round(2)}MB"
      puts "Total retained memory: #{(report.total_retained_memsize / 1.megabyte).round(2)}MB"
    end

    it 'benchmarks search operations' do
      puts "\n=== RAG Search Benchmark ==="
      
      Benchmark.ips do |x|
        x.config(time: 5, warmup: 2)
        
        x.report("RAG Search") do
          post '/api/search/rag', params: search_params, as: :json
        end
        
        x.compare!
      end
    end
  end

  describe 'Health Check Performance' do
    it 'health check responds quickly' do
      response_times = []
      
      20.times do
        start_time = Time.current
        get '/api/search/health'
        end_time = Time.current
        
        expect(response).to have_http_status(:success)
        response_times << (end_time - start_time) * 1000
      end
      
      average_time = response_times.sum / response_times.size
      expect(average_time).to be < 50, "Health check average time #{average_time}ms exceeds 50ms limit"
      
      puts "Health check average response time: #{average_time.round(2)}ms"
    end
  end

  describe 'Vector Search Performance' do
    it 'vector similarity search is efficient' do
      service = VectorSearchService.new
      query_vector = Array.new(1536, rand)
      
      response_times = []
      
      10.times do
        start_time = Time.current
        results = service.search(query_vector, limit: 5)
        end_time = Time.current
        
        expect(results).to be_present
        response_times << (end_time - start_time) * 1000
      end
      
      average_time = response_times.sum / response_times.size
      expect(average_time).to be < 100, "Vector search average time #{average_time}ms exceeds 100ms limit"
      
      puts "Vector search average time: #{average_time.round(2)}ms"
    end
  end

  describe 'Rate Limiting Performance' do
    it 'handles rate limiting efficiently' do
      # Test rate limiting doesn't significantly impact performance
      start_time = Time.current
      
      15.times do |i|
        post '/api/search/rag', params: search_params, as: :json
        
        if i < 10
          expect(response).to have_http_status(:success)
        else
          # Should hit rate limit after 10 requests
          expect(response).to have_http_status(:too_many_requests)
        end
      end
      
      end_time = Time.current
      total_time = (end_time - start_time) * 1000
      
      # Rate limiting shouldn't add significant overhead
      expect(total_time).to be < 5000, "Rate limiting test took #{total_time}ms, too slow"
      
      puts "Rate limiting test completed in: #{total_time.round(2)}ms"
    end
  end
end