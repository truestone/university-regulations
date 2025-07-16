# frozen_string_literal: true

module Api
  # 개선된 벡터 검색 API 컨트롤러
  class SearchController < ApplicationController
    skip_before_action :verify_authenticity_token, only: [:create, :vector_search, :hybrid_search, :rag]
    
    before_action :validate_query_params, only: [:create, :vector_search, :hybrid_search]
    before_action :log_api_request
    before_action :check_rate_limit, only: [:vector_search, :hybrid_search, :rag]
    
    # 기본 키워드 검색 엔드포인트 (POST /api/search)
    def create
      begin
        start_time = Time.current
        
        # 키워드 검색 실행
        search_results = perform_keyword_search(@query, search_options)
        
        # 응답 생성
        response_data = build_search_response(
          query: @query,
          results: search_results,
          search_type: 'keyword',
          execution_time: calculate_execution_time(start_time)
        )
        
        # 검색 로그 기록
        log_search_query(@query, search_results.size, calculate_execution_time(start_time))
        
        render json: response_data, status: :ok
        
      rescue => e
        handle_search_error(e, 'keyword')
      end
    end
    
    # 벡터 검색 엔드포인트 (POST /api/search/vector)
    def vector_search
      begin
        start_time = Time.current
        
        # VectorSearchService를 사용한 실제 벡터 검색
        vector_service = VectorSearchService.new(@query, search_options)
        search_results = vector_service.search
        
        # 응답 생성
        response_data = build_search_response(
          query: @query,
          results: search_results,
          search_type: 'vector',
          execution_time: calculate_execution_time(start_time),
          metadata: vector_service.search_stats
        )
        
        # 검색 로그 기록
        log_search_query(@query, search_results.size, calculate_execution_time(start_time), 'vector')
        
        render json: response_data, status: :ok
        
      rescue => e
        handle_search_error(e, 'vector')
      end
    end
    
    # 하이브리드 검색 엔드포인트 (POST /api/search/hybrid)
    def hybrid_search
      begin
        start_time = Time.current
        
        # VectorSearchService를 사용한 하이브리드 검색
        vector_service = VectorSearchService.new(@query, search_options)
        search_results = vector_service.hybrid_search
        
        # 응답 생성
        response_data = build_search_response(
          query: @query,
          results: search_results,
          search_type: 'hybrid',
          execution_time: calculate_execution_time(start_time),
          metadata: vector_service.search_stats
        )
        
        # 검색 로그 기록
        log_search_query(@query, search_results.size, calculate_execution_time(start_time), 'hybrid')
        
        render json: response_data, status: :ok
        
      rescue => e
        handle_search_error(e, 'hybrid')
      end
    end
    
    # RAG 검색 엔드포인트 (POST /api/search/rag)
    def rag
      begin
        start_time = Time.current
        
        # RAG 오케스트레이터 실행
        rag_result = RagOrchestratorService.execute(@query, rag_options)
        
        if rag_result.nil?
          render json: { 
            success: false, 
            error: "RAG 처리 중 오류가 발생했습니다.",
            query: @query
          }, status: :unprocessable_entity
          return
        end
        
        # 응답 생성
        response_data = {
          success: true,
          query: @query,
          answer: rag_result[:answer],
          sources: format_rag_sources(rag_result[:sources]),
          search_type: 'rag',
          metadata: {
            model: params[:model] || 'gpt-4',
            response_format: params[:response_format] || 'detailed',
            execution_time: calculate_execution_time(start_time),
            cached: rag_result[:cached] || false,
            pipeline_steps: rag_result[:pipeline_steps]
          },
          timestamp: Time.current.iso8601
        }
        
        # 검색 로그 기록
        sources_count = rag_result[:sources]&.size || 0
        log_search_query(@query, sources_count, calculate_execution_time(start_time), 'rag')
        
        render json: response_data, status: :ok
        
      rescue => e
        handle_search_error(e, 'rag')
      end
    end
    
    # 검색 통계 엔드포인트 (GET /api/search/stats)
    def stats
      begin
        stats_data = {
          success: true,
          stats: {
            total_searches: SearchQuery.count,
            recent_searches: SearchQuery.where('created_at > ?', 24.hours.ago).count,
            popular_queries: SearchQuery.group(:query_text)
                                       .where('created_at > ?', 7.days.ago)
                                       .order('count(*) DESC')
                                       .limit(10)
                                       .count,
            avg_response_time: SearchQuery.where('created_at > ?', 24.hours.ago)
                                         .average(:response_time_ms)&.round(2) || 0
          },
          services: service_health_check,
          timestamp: Time.current.iso8601
        }
        
        render json: stats_data, status: :ok
        
      rescue => e
        Rails.logger.error "Stats error: #{e.message}"
        render json: { 
          success: false, 
          error: "통계 조회 중 오류가 발생했습니다." 
        }, status: :internal_server_error
      end
    end
    
    # A/B 테스트 엔드포인트 (POST /api/search/ab_test)
    def ab_test
      begin
        start_time = Time.current
        
        # A/B 테스트 그룹 결정
        test_group = determine_ab_test_group
        
        case test_group
        when 'vector'
          vector_service = VectorSearchService.new(@query, search_options)
          search_results = vector_service.search
          search_type = 'vector'
        when 'hybrid'
          vector_service = VectorSearchService.new(@query, search_options)
          search_results = vector_service.hybrid_search
          search_type = 'hybrid'
        else
          search_results = perform_keyword_search(@query, search_options)
          search_type = 'keyword'
        end
        
        # 응답 생성
        response_data = build_search_response(
          query: @query,
          results: search_results,
          search_type: search_type,
          execution_time: calculate_execution_time(start_time),
          metadata: { ab_test_group: test_group }
        )
        
        # A/B 테스트 로그 기록
        log_ab_test_result(test_group, @query, search_results.size, calculate_execution_time(start_time))
        
        render json: response_data, status: :ok
        
      rescue => e
        handle_search_error(e, 'ab_test')
      end
    end
    
    # 헬스 체크 엔드포인트 (GET /api/health)
    def health
      health_data = {
        status: 'healthy',
        services: service_health_check,
        timestamp: Time.current.iso8601
      }
      
      # 서비스 중 하나라도 unhealthy면 전체 상태를 unhealthy로 설정
      overall_status = health_data[:services].values.all? { |s| s[:status] == 'healthy' } ? 'healthy' : 'unhealthy'
      health_data[:status] = overall_status
      
      status_code = overall_status == 'healthy' ? :ok : :service_unavailable
      render json: health_data, status: status_code
    end
    
    private
    
    # 쿼리 파라미터 검증
    def validate_query_params
      @query = params[:query]&.to_s&.strip
      
      if @query.blank?
        render json: { 
          success: false, 
          error: "검색어를 입력해주세요." 
        }, status: :bad_request
        return false
      end
      
      if @query.length > 500
        render json: { 
          success: false, 
          error: "검색어는 500자를 초과할 수 없습니다." 
        }, status: :bad_request
        return false
      end
      
      true
    end
    
    # API 요청 로깅
    def log_api_request
      Rails.logger.info "API Request: #{request.method} #{request.path}"
      Rails.logger.info "Params: #{params.except(:controller, :action).to_json}"
      Rails.logger.info "IP: #{request.remote_ip}"
      Rails.logger.info "User-Agent: #{request.user_agent}"
    end
    
    # 속도 제한 확인
    def check_rate_limit
      # Redis를 사용한 간단한 속도 제한 (분당 60회)
      client_ip = request.remote_ip
      rate_limit_key = "rate_limit:#{client_ip}:#{Time.current.strftime('%Y%m%d%H%M')}"
      
      current_count = Rails.cache.read(rate_limit_key) || 0
      
      if current_count >= 60
        render json: { 
          success: false, 
          error: "요청 한도를 초과했습니다. 잠시 후 다시 시도해주세요." 
        }, status: :too_many_requests
        return false
      end
      
      Rails.cache.write(rate_limit_key, current_count + 1, expires_in: 1.minute)
      true
    end
    
    # 키워드 검색 실행
    def perform_keyword_search(query, options = {})
      limit = options[:limit] || 10
      
      # 안전한 키워드 검색 (SQL 인젝션 방지)
      keywords = query.split(/\s+/).map(&:strip).reject(&:empty?)
      
      return [] if keywords.empty?
      
      # ILIKE를 사용한 안전한 검색
      search_conditions = keywords.map do |keyword|
        sanitized_keyword = ActiveRecord::Base.connection.quote("%#{keyword}%")
        "(articles.content ILIKE #{sanitized_keyword} OR articles.title ILIKE #{sanitized_keyword} OR regulations.title ILIKE #{sanitized_keyword})"
      end.join(' OR ')
      
      Article.joins(:regulation)
             .where(search_conditions)
             .where(is_active: true)
             .limit(limit)
             .includes(:regulation)
             .map { |article| format_article_result(article, 'keyword') }
    end
    
    # 검색 옵션 생성
    def search_options
      {
        limit: [params[:limit]&.to_i || 10, 50].min, # 최대 50개로 제한
        similarity_threshold: params[:similarity_threshold]&.to_f || 0.7,
        include_context: params[:include_context] != 'false',
        boost_recent: params[:boost_recent] == 'true',
        filter_active_only: params[:filter_active_only] != 'false'
      }
    end
    
    # RAG 옵션 생성
    def rag_options
      {
        model: params[:model] || 'gpt-4',
        response_format: params[:response_format] || 'detailed',
        max_sources: params[:max_sources]&.to_i || 5,
        temperature: params[:temperature]&.to_f || 0.1
      }
    end
    
    # 검색 응답 생성
    def build_search_response(query:, results:, search_type:, execution_time:, metadata: {})
      {
        success: true,
        query: query,
        search_type: search_type,
        results: results,
        count: results.size,
        message: generate_search_message(results.size, search_type),
        metadata: {
          execution_time_ms: execution_time,
          **metadata
        },
        timestamp: Time.current.iso8601
      }
    end
    
    # 조문 결과 포맷팅
    def format_article_result(article, search_type, similarity_score = nil)
      {
        id: article.id,
        regulation_title: article.regulation.title,
        regulation_code: article.regulation.regulation_code,
        article_number: article.number,
        article_title: article.title,
        content: truncate_content(article.content),
        full_context: article.full_context,
        search_type: search_type,
        similarity_score: similarity_score,
        relevance_score: similarity_score || calculate_keyword_relevance(article, @query),
        url: article_url(article)
      }
    end
    
    # RAG 소스 포맷팅
    def format_rag_sources(sources)
      return [] unless sources.is_a?(Array)
      
      sources.map do |source|
        if source.is_a?(Article)
          format_article_result(source, 'rag', source.try(:similarity_score))
        else
          source
        end
      end
    end
    
    # 콘텐츠 자르기
    def truncate_content(content, length = 200)
      return content if content.length <= length
      content[0..length] + "..."
    end
    
    # 키워드 관련성 점수 계산
    def calculate_keyword_relevance(article, query)
      keywords = query.downcase.split(/\s+/)
      content_lower = article.content.downcase
      title_lower = article.title.downcase
      
      keyword_matches = keywords.count { |keyword| 
        content_lower.include?(keyword) || title_lower.include?(keyword) 
      }
      
      # 기본 점수 + 키워드 매치 보너스
      base_score = 0.5
      keyword_bonus = (keyword_matches.to_f / keywords.size) * 0.4
      
      (base_score + keyword_bonus).round(3)
    end
    
    # 검색 메시지 생성
    def generate_search_message(count, search_type)
      type_name = case search_type
                  when 'vector' then '벡터 검색'
                  when 'hybrid' then '하이브리드 검색'
                  when 'keyword' then '키워드 검색'
                  when 'rag' then 'RAG 검색'
                  else '검색'
                  end
      
      "#{type_name}으로 #{count}개의 관련 조문을 찾았습니다."
    end
    
    # 실행 시간 계산
    def calculate_execution_time(start_time)
      ((Time.current - start_time) * 1000).round(2)
    end
    
    # 검색 쿼리 로그 기록
    def log_search_query(query, results_count, response_time, search_type = 'keyword')
      SearchQuery.create!(
        query_text: query,
        results_count: results_count,
        response_time_ms: response_time,
        search_type: search_type,
        ip_address: request.remote_ip,
        user_agent: request.user_agent,
        metadata: { search_type: search_type, timestamp: Time.current.iso8601 }
      )
    rescue => e
      Rails.logger.error "Failed to log search query: #{e.message}"
    end
    
    # A/B 테스트 그룹 결정
    def determine_ab_test_group
      # IP 주소 기반으로 일관된 그룹 할당
      hash = Digest::MD5.hexdigest(request.remote_ip).to_i(16)
      case hash % 3
      when 0 then 'keyword'
      when 1 then 'vector'
      else 'hybrid'
      end
    end
    
    # A/B 테스트 결과 로그
    def log_ab_test_result(group, query, results_count, response_time)
      Rails.logger.info "A/B Test: group=#{group}, query=#{query.truncate(50)}, results=#{results_count}, time=#{response_time}ms"
    end
    
    # 서비스 헬스 체크
    def service_health_check
      {
        database: check_database_health,
        redis: check_redis_health,
        pgvector: check_pgvector_health,
        openai: check_openai_health
      }
    end
    
    # 데이터베이스 헬스 체크
    def check_database_health
      begin
        ActiveRecord::Base.connection.execute('SELECT 1')
        { status: 'healthy', response_time: 0 }
      rescue => e
        { status: 'unhealthy', error: e.message }
      end
    end
    
    # Redis 헬스 체크
    def check_redis_health
      begin
        Rails.cache.write('health_check', 'ok', expires_in: 1.second)
        Rails.cache.read('health_check')
        { status: 'healthy', response_time: 0 }
      rescue => e
        { status: 'unhealthy', error: e.message }
      end
    end
    
    # pgvector 헬스 체크
    def check_pgvector_health
      begin
        ActiveRecord::Base.connection.execute("SELECT '[1,2,3]'::vector")
        { status: 'healthy', response_time: 0 }
      rescue => e
        { status: 'unhealthy', error: e.message }
      end
    end
    
    # OpenAI 헬스 체크
    def check_openai_health
      begin
        # 간단한 API 키 유효성 확인
        api_key = Rails.application.credentials.dig(:openai_api_key) || ENV['OPENAI_API_KEY']
        if api_key.present? && api_key.length > 10
          { status: 'healthy', response_time: 0, message: 'API key configured' }
        else
          { status: 'unhealthy', error: 'API key not configured or invalid' }
        end
      rescue => e
        { status: 'unhealthy', error: e.message }
      end
    end
    
    # 검색 오류 처리
    def handle_search_error(error, search_type)
      Rails.logger.error "#{search_type.capitalize} search error: #{error.message}"
      Rails.logger.error error.backtrace.join("\n")
      
      error_response = {
        success: false,
        error: "#{search_type} 검색 중 오류가 발생했습니다.",
        query: @query,
        search_type: search_type,
        timestamp: Time.current.iso8601
      }
      
      # 개발 환경에서는 상세 오류 정보 포함
      if Rails.env.development?
        error_response[:debug] = {
          message: error.message,
          backtrace: error.backtrace.first(5)
        }
      end
      
      status_code = case error
                    when ActiveRecord::RecordNotFound
                      :not_found
                    when ArgumentError, ActiveModel::ValidationError
                      :bad_request
                    else
                      :internal_server_error
                    end
      
      render json: error_response, status: status_code
    end
    
    # 조문 URL 생성
    def article_url(article)
      # 실제 프론트엔드 URL 구조에 맞게 수정 필요
      "/regulations/#{article.regulation.regulation_code}/articles/#{article.number}"
    end
  end
end