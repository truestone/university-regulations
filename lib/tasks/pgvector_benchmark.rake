# frozen_string_literal: true

namespace :pgvector do
  desc "Benchmark different pgvector configurations"
  task :benchmark => :environment do
    puts "🚀 pgvector 성능 벤치마크 시작"
    puts "=" * 60
    
    # 테스트용 임베딩 생성
    test_embeddings = generate_test_embeddings(10)
    
    # 다양한 설정으로 벤치마크 실행
    configurations = [
      { distance_function: 'cosine', use_ivfflat: false, ef_search: 16 },
      { distance_function: 'cosine', use_ivfflat: false, ef_search: 40 },
      { distance_function: 'cosine', use_ivfflat: false, ef_search: 64 },
      { distance_function: 'cosine', use_ivfflat: true, ef_search: 40 },
      { distance_function: 'l2', use_ivfflat: false, ef_search: 40 },
      { distance_function: 'inner_product', use_ivfflat: false, ef_search: 40 }
    ]
    
    results = []
    
    configurations.each_with_index do |config, index|
      puts "\n📊 설정 #{index + 1}: #{config.inspect}"
      
      benchmark_result = benchmark_configuration(test_embeddings, config)
      results << benchmark_result.merge(config)
      
      puts "  평균 응답시간: #{benchmark_result[:avg_time]}ms"
      puts "  평균 결과 수: #{benchmark_result[:avg_results]}"
      puts "  성공률: #{benchmark_result[:success_rate]}%"
    end
    
    # 결과 요약
    puts "\n" + "=" * 60
    puts "📈 벤치마크 결과 요약"
    puts "=" * 60
    
    best_config = results.min_by { |r| r[:avg_time] }
    puts "🏆 최고 성능 설정:"
    puts "  #{best_config.except(:avg_time, :avg_results, :success_rate, :errors).inspect}"
    puts "  평균 응답시간: #{best_config[:avg_time]}ms"
    
    # 결과를 파일로 저장
    save_benchmark_results(results)
  end

  desc "Analyze query performance with EXPLAIN"
  task :analyze_queries => :environment do
    puts "🔍 쿼리 성능 분석"
    puts "=" * 40
    
    # 샘플 임베딩으로 분석
    sample_embedding = Array.new(1536, 0.1)
    
    configurations = [
      { distance_function: 'cosine', use_ivfflat: false, ef_search: 40 },
      { distance_function: 'cosine', use_ivfflat: true, ef_search: 40 }
    ]
    
    configurations.each do |config|
      puts "\n📊 분석 중: #{config.inspect}"
      
      optimizer = PgvectorOptimizer.new(embedding: sample_embedding, **config)
      analysis = optimizer.analyze_query_performance
      
      puts "  실행 시간: #{analysis[:execution_time]}ms"
      puts "  계획 시간: #{analysis[:planning_time]}ms"
      puts "  반환 행 수: #{analysis[:rows_returned]}"
      puts "  사용된 인덱스: #{analysis[:index_used]&.dig(:name) || 'None'}"
      puts "  버퍼 히트: #{analysis[:buffers_hit]}"
      puts "  버퍼 읽기: #{analysis[:buffers_read]}"
    end
  end

  desc "Test concurrent query load"
  task :load_test => :environment do
    puts "⚡ 동시 쿼리 부하 테스트"
    puts "=" * 40
    
    # 테스트 설정
    concurrent_users = [1, 5, 10, 20].map(&:to_i)
    queries_per_user = 10
    
    test_embeddings = generate_test_embeddings(5)
    
    concurrent_users.each do |user_count|
      puts "\n👥 동시 사용자 수: #{user_count}"
      
      start_time = Time.current
      
      threads = user_count.times.map do |user_id|
        Thread.new do
          user_results = []
          queries_per_user.times do |query_id|
            embedding = test_embeddings.sample
            
            query_start = Time.current
            begin
              results = PgvectorOptimizer.search(
                embedding: embedding,
                limit: 10,
                similarity_threshold: 0.7
              )
              query_time = ((Time.current - query_start) * 1000).round(2)
              user_results << { success: true, time: query_time, results: results.length }
            rescue => e
              query_time = ((Time.current - query_start) * 1000).round(2)
              user_results << { success: false, time: query_time, error: e.message }
            end
          end
          user_results
        end
      end
      
      # 모든 스레드 완료 대기
      all_results = threads.map(&:value).flatten
      total_time = ((Time.current - start_time) * 1000).round(2)
      
      # 결과 분석
      successful_queries = all_results.select { |r| r[:success] }
      failed_queries = all_results.reject { |r| r[:success] }
      
      puts "  총 실행 시간: #{total_time}ms"
      puts "  성공한 쿼리: #{successful_queries.length}/#{all_results.length}"
      puts "  평균 쿼리 시간: #{successful_queries.map { |r| r[:time] }.sum / successful_queries.length}ms" if successful_queries.any?
      puts "  실패율: #{(failed_queries.length.to_f / all_results.length * 100).round(2)}%"
      puts "  초당 쿼리 수: #{(all_results.length / (total_time / 1000.0)).round(2)} QPS"
    end
  end

  desc "Optimize index parameters"
  task :optimize_indexes => :environment do
    puts "🔧 인덱스 파라미터 최적화"
    puts "=" * 40
    
    article_count = Article.where.not(embedding: nil).count
    puts "📊 임베딩이 있는 조문 수: #{article_count}"
    
    # 권장 파라미터 계산
    recommended = PgvectorOptimizer.recommend_parameters(
      article_count: article_count,
      query_frequency: :medium
    )
    
    puts "\n💡 권장 설정:"
    recommended.each do |key, value|
      puts "  #{key}: #{value}"
    end
    
    # 현재 인덱스 상태 확인
    puts "\n📋 현재 인덱스 상태:"
    check_index_status
  end

  private

  def generate_test_embeddings(count)
    count.times.map do
      Array.new(1536) { rand(-1.0..1.0) }
    end
  end

  def benchmark_configuration(test_embeddings, config)
    times = []
    results_counts = []
    errors = []
    
    test_embeddings.each do |embedding|
      start_time = Time.current
      begin
        results = PgvectorOptimizer.search(embedding: embedding, **config)
        execution_time = ((Time.current - start_time) * 1000).round(2)
        
        times << execution_time
        results_counts << results.length
      rescue => e
        execution_time = ((Time.current - start_time) * 1000).round(2)
        times << execution_time
        results_counts << 0
        errors << e.message
      end
    end
    
    {
      avg_time: (times.sum / times.length).round(2),
      avg_results: (results_counts.sum / results_counts.length).round(2),
      success_rate: ((test_embeddings.length - errors.length).to_f / test_embeddings.length * 100).round(2),
      errors: errors
    }
  end

  def save_benchmark_results(results)
    filename = "tmp/pgvector_benchmark_#{Time.current.strftime('%Y%m%d_%H%M%S')}.json"
    File.write(filename, JSON.pretty_generate(results))
    puts "\n💾 벤치마크 결과 저장: #{filename}"
  end

  def check_index_status
    sql = <<~SQL
      SELECT 
        schemaname,
        tablename,
        indexname,
        indexdef
      FROM pg_indexes 
      WHERE tablename IN ('articles', 'search_queries')
        AND indexdef LIKE '%embedding%'
      ORDER BY tablename, indexname;
    SQL
    
    result = ActiveRecord::Base.connection.execute(sql)
    result.each do |row|
      puts "  #{row['tablename']}.#{row['indexname']}"
      puts "    #{row['indexdef']}"
    end
  end
end