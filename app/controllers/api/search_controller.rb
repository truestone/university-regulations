# frozen_string_literal: true

module Api
  # 벡터 검색 및 RAG 답변 API 컨트롤러
  class SearchController < ApplicationController
    before_action :validate_search_params, only: [:vector_search, :hybrid_search, :rag_answer]
    before_action :check_rate_limit, only: [:rag_answer]
    before_action :log_api_request
    
    # 벡터 유사도 검색
    def vector_search
      search_service = VectorSearchService.new(search_params[:query], search_options)
      results = search_service.search
      
      render json: {
        success: true,
        query: search_params[:query],
        results: format_search_results(results),
        stats: search_service.search_stats,
        timestamp: Time.current.iso8601
      }
    end

    # 하이브리드 검색 (벡터 + 키워드)
    def hybrid_search
      search_service = VectorSearchService.new(search_params[:query], search_options)
      results = search_service.hybrid_search
      
      render json: {
        success: true,
        query: search_params[:query],
        results: format_hybrid_results(results),
        stats: search_service.search_stats,
        timestamp: Time.current.iso8601
      }
    end

    # 유사 조문 검색
    def similar_articles
      article_id = params[:article_id]
      limit = [params[:limit].to_i, 20].min
      limit = 5 if limit <= 0
      
      article = Article.find(article_id)
      search_service = VectorSearchService.new('')
      similar_articles = search_service.find_similar_articles(article_id, limit: limit)
      
      render json: {
        success: true,
        source_article: format_article_summary(article),
        similar_articles: format_similar_articles(similar_articles),
        count: similar_articles.size,
        timestamp: Time.current.iso8601
      }
      
    rescue ActiveRecord::RecordNotFound
      render json: {
        success: false,
        error: "Article with ID #{article_id} not found"
      }, status: 404
    end

    # 검색 제안 (자동완성)
    def suggestions
      query = params[:query].to_s.strip
      
      if query.length < 2
        render json: { suggestions: [] }
        return
      end
      
      # 제목과 내용에서 부분 일치하는 조문들의 제목 추출
      suggestions = Article.joins(:regulation)
                          .where('articles.title ILIKE ? OR articles.content ILIKE ?', 
                                 "%#{query}%", "%#{query}%")
                          .where(is_active: true)
                          .limit(10)
                          .pluck(:title)
                          .uniq
                          .sort
      
      render json: { suggestions: suggestions }
    end

    # 검색 통계
    def stats
      stats = {
        total_articles: Article.where(is_active: true).count,
        articles_with_embeddings: Article.where(is_active: true).where.not(embedding: nil).count,
        recent_searches: get_recent_search_stats,
        popular_queries: get_popular_queries
      }
      
      render json: {
        success: true,
        stats: stats,
        timestamp: Time.current.iso8601
      }
    end

    private

    def search_params
      params.permit(:query, :limit, :similarity_threshold, :include_context, :boost_recent, :filter_active_only)
    end

    def search_options
      options = {}
      
      options[:limit] = [search_params[:limit].to_i, 50].min if search_params[:limit].present?
      options[:limit] = 10 if options[:limit] <= 0
      
      if search_params[:similarity_threshold].present?
        threshold = search_params[:similarity_threshold].to_f
        options[:similarity_threshold] = [[threshold, 0.0].max, 1.0].min
      end
      
      options[:include_context] = search_params[:include_context] != 'false'
      options[:boost_recent] = search_params[:boost_recent] == 'true'
      options[:filter_active_only] = search_params[:filter_active_only] != 'false'
      
      options
    end

    def validate_search_params
      if search_params[:query].blank?
        render json: {
          success: false,
          error: "Query parameter is required"
        }, status: 400
        return
      end
      
      if search_params[:query].length > 1000
        render json: {
          success: false,
          error: "Query is too long (maximum 1000 characters)"
        }, status: 400
        return
      end
    end

    def format_search_results(results)
      results.map do |article|
        {
          id: article.id,
          title: article.title,
          content: truncate_content(article.content),
          highlighted_content: article.respond_to?(:highlighted_content) ? article.highlighted_content : nil,
          similarity_score: article.respond_to?(:similarity_score) ? article.similarity_score : nil,
          context_path: article.respond_to?(:context_path) ? article.context_path : nil,
          regulation: {
            title: article.respond_to?(:regulation_title) ? article.regulation_title : article.regulation&.title,
            code: article.respond_to?(:regulation_code) ? article.regulation_code : article.regulation&.regulation_code
          },
          article_number: article.number,
          updated_at: article.updated_at.iso8601
        }
      end
    end

    def format_hybrid_results(results)
      results.map do |article|
        {
          id: article.id,
          title: article.title,
          content: truncate_content(article.content),
          highlighted_content: article.respond_to?(:highlighted_content) ? article.highlighted_content : nil,
          scores: {
            vector: article.respond_to?(:vector_score) ? article.vector_score : nil,
            keyword: article.respond_to?(:keyword_score) ? article.keyword_score : nil,
            combined: article.respond_to?(:combined_score) ? article.combined_score : nil
          },
          ranks: {
            vector: article.respond_to?(:vector_rank) ? article.vector_rank : nil,
            keyword: article.respond_to?(:keyword_rank) ? article.keyword_rank : nil
          },
          context_path: article.respond_to?(:context_path) ? article.context_path : nil,
          regulation: {
            title: article.respond_to?(:regulation_title) ? article.regulation_title : article.regulation&.title,
            code: article.respond_to?(:regulation_code) ? article.regulation_code : article.regulation&.regulation_code
          },
          article_number: article.number,
          updated_at: article.updated_at.iso8601
        }
      end
    end

    def format_similar_articles(articles)
      articles.map do |article|
        {
          id: article.id,
          title: article.title,
          content: truncate_content(article.content),
          similarity_score: article.respond_to?(:similarity_score) ? article.similarity_score : nil,
          regulation: {
            title: article.respond_to?(:regulation_title) ? article.regulation_title : article.regulation&.title,
            code: article.respond_to?(:regulation_code) ? article.regulation_code : article.regulation&.regulation_code
          },
          article_number: article.number,
          updated_at: article.updated_at.iso8601
        }
      end
    end

    def format_article_summary(article)
      {
        id: article.id,
        title: article.title,
        content: truncate_content(article.content),
        regulation: {
          title: article.regulation&.title,
          code: article.regulation&.regulation_code
        },
        article_number: article.number
      }
    end

    def truncate_content(content, length: 200)
      return content if content.blank? || content.length <= length
      
      "#{content[0...length]}..."
    end

    def get_recent_search_stats
      # 실제 구현에서는 검색 로그를 저장하고 분석
      # 여기서는 더미 데이터 반환
      {
        last_24_hours: 0,
        last_week: 0,
        last_month: 0
      }
    end

    def get_popular_queries
      # 실제 구현에서는 검색 로그에서 인기 쿼리 추출
      # 여기서는 더미 데이터 반환
      []
    end
  end
end
  # RAG 기반 질문 답변 API
  def rag_answer
    start_time = Time.current
    
    begin
      # 1. 캐시 확인
      cache_key = generate_cache_key(search_params[:query], search_options)
      cached_result = Rails.cache.read(cache_key)
      
      if cached_result
        Rails.logger.info "Cache hit for query: #{search_params[:query].truncate(50)}"
        return render json: cached_result.merge(
          cached: true,
          cache_key: cache_key,
          timestamp: Time.current.iso8601
        )
      end

      # 2. 벡터 검색 실행
      search_service = VectorSearchService.new(search_params[:query], search_options)
      search_results = search_service.search

      if search_results.empty?
        return render json: {
          success: false,
          error: "검색 결과가 없습니다. 다른 키워드로 시도해보세요.",
          query: search_params[:query],
          timestamp: Time.current.iso8601
        }, status: 404
      end

      # 3. GPT-4 답변 생성
      answer_result = GptAnswerService.generate_answer(
        question: search_params[:query],
        search_results: search_results,
        model: gpt_model,
        temperature: gpt_temperature,
        response_format: response_format
      )

      # 4. 응답 구성
      response_data = {
        success: true,
        query: search_params[:query],
        answer: answer_result[:answer],
        sources: answer_result[:sources],
        metadata: {
          search_stats: search_service.search_stats,
          gpt_metadata: answer_result[:metadata],
          execution_time_ms: ((Time.current - start_time) * 1000).round(2),
          model_used: gpt_model,
          response_format: response_format
        },
        cached: false,
        timestamp: Time.current.iso8601
      }

      # 5. 캐시 저장
      Rails.cache.write(cache_key, response_data, expires_in: cache_ttl)

      # 6. 검색 로그 저장
      log_search_query(search_params[:query], search_results, answer_result, start_time)

      render json: response_data

    rescue => e
      handle_rag_error(e, start_time)
    end
  end

  # A/B 테스트용 답변 생성
  def rag_ab_test
    start_time = Time.current
    
    begin
      # 벡터 검색 실행
      search_service = VectorSearchService.new(search_params[:query], search_options)
      search_results = search_service.search

      if search_results.empty?
        return render json: {
          success: false,
          error: "검색 결과가 없습니다.",
          query: search_params[:query]
        }, status: 404
      end

      # A/B 테스트 답변 생성
      ab_results = GptAnswerService.generate_ab_test_answers(
        question: search_params[:query],
        search_results: search_results
      )

      render json: {
        success: true,
        query: search_params[:query],
        variant_a: ab_results[:variant_a],
        variant_b: ab_results[:variant_b],
        test_metadata: ab_results[:test_metadata],
        execution_time_ms: ((Time.current - start_time) * 1000).round(2),
        timestamp: Time.current.iso8601
      }

    rescue => e
      handle_rag_error(e, start_time)
    end
  end

  # 검색 통계 API
  def search_stats
    stats = {
      total_searches: SearchQuery.count,
      recent_searches: SearchQuery.recent.count,
      popular_queries: SearchQuery.popular_queries(limit: 10),
      performance_stats: SearchQuery.performance_stats,
      system_health: {
        articles_with_embeddings: Article.where.not(embedding: nil).count,
        total_articles: Article.count,
        embedding_coverage: calculate_embedding_coverage
      }
    }

    render json: {
      success: true,
      stats: stats,
      timestamp: Time.current.iso8601
    }
  end

  # 시스템 상태 확인
  def health
    health_status = {
      status: "healthy",
      services: {
        database: check_database_health,
        redis: check_redis_health,
        openai: check_openai_health,
        pgvector: check_pgvector_health
      },
      version: Rails.application.class.module_parent_name,
      timestamp: Time.current.iso8601
    }

    # 전체 상태 결정
    overall_healthy = health_status[:services].values.all? { |service| service[:status] == "healthy" }
    health_status[:status] = overall_healthy ? "healthy" : "degraded"

    status_code = overall_healthy ? 200 : 503
    render json: health_status, status: status_code
  end

  private

  # 캐시 키 생성
  def generate_cache_key(query, options)
    content = "#{query}:#{options.to_json}"
    "rag_answer:#{Digest::MD5.hexdigest(content)}"
  end

  # GPT 모델 선택
  def gpt_model
    params[:model] || "gpt-4"
  end

  # GPT 온도 설정
  def gpt_temperature
    temp = params[:temperature]&.to_f || 0.3
    [[temp, 0.0].max, 2.0].min  # 0.0 ~ 2.0 범위로 제한
  end

  # 응답 형식
  def response_format
    format = params[:response_format] || "detailed"
    %w[brief detailed structured].include?(format) ? format : "detailed"
  end

  # 캐시 TTL
  def cache_ttl
    ttl = params[:cache_ttl]&.to_i || 24.hours
    [[ttl, 1.minute].max, 7.days].min  # 1분 ~ 7일 범위로 제한
  end

  # 레이트 리밋 확인
  def check_rate_limit
    client_ip = request.remote_ip
    rate_limit_key = "rate_limit:#{client_ip}"
    
    current_count = Rails.cache.read(rate_limit_key) || 0
    limit = rate_limit_per_hour
    
    if current_count >= limit
      render json: {
        success: false,
        error: "Rate limit exceeded. Please try again later.",
        limit: limit,
        reset_time: 1.hour.from_now.iso8601
      }, status: 429
      return
    end
    
    Rails.cache.write(rate_limit_key, current_count + 1, expires_in: 1.hour)
  end

  # 시간당 요청 제한
  def rate_limit_per_hour
    params[:rate_limit]&.to_i || 100  # 기본 100회/시간
  end

  # API 요청 로깅
  def log_api_request
    Rails.logger.info "API Request: #{request.method} #{request.path}"
    Rails.logger.info "Params: #{params.except(:controller, :action).to_json}"
    Rails.logger.info "IP: #{request.remote_ip}"
    Rails.logger.info "User-Agent: #{request.user_agent}"
  end

  # 검색 쿼리 로깅
  def log_search_query(query, search_results, answer_result, start_time)
    execution_time = ((Time.current - start_time) * 1000).round(2)
    
    SearchQuery.log_search(
      query_text: query,
      embedding: search_results.first&.dig(:embedding) || [],
      results_count: search_results.length,
      response_time_ms: execution_time,
      metadata: {
        gpt_model: gpt_model,
        response_format: response_format,
        quality_score: answer_result[:metadata][:quality_score],
        ip_address: request.remote_ip,
        user_agent: request.user_agent
      }
    )
  end

  # RAG 에러 처리
  def handle_rag_error(error, start_time)
    execution_time = ((Time.current - start_time) * 1000).round(2)
    
    Rails.logger.error "RAG API Error: #{error.message}"
    Rails.logger.error error.backtrace.join("\n") if Rails.env.development?

    error_response = {
      success: false,
      error: "서비스에 일시적인 문제가 발생했습니다. 잠시 후 다시 시도해 주세요.",
      error_type: error.class.name,
      execution_time_ms: execution_time,
      timestamp: Time.current.iso8601
    }

    # 개발 환경에서는 상세 에러 정보 포함
    if Rails.env.development?
      error_response[:debug] = {
        message: error.message,
        backtrace: error.backtrace.first(5)
      }
    end

    status_code = case error
                  when OpenAI::Error then 502
                  when ActiveRecord::RecordNotFound then 404
                  when ArgumentError then 400
                  else 500
                  end

    render json: error_response, status: status_code
  end

  # 임베딩 커버리지 계산
  def calculate_embedding_coverage
    total = Article.count
    return 0 if total == 0
    
    with_embedding = Article.where.not(embedding: nil).count
    ((with_embedding.to_f / total) * 100).round(2)
  end

  # 데이터베이스 상태 확인
  def check_database_health
    begin
      ActiveRecord::Base.connection.execute("SELECT 1")
      { status: "healthy", response_time_ms: 0 }
    rescue => e
      { status: "unhealthy", error: e.message }
    end
  end

  # Redis 상태 확인
  def check_redis_health
    begin
      start_time = Time.current
      Rails.cache.write("health_check", "ok", expires_in: 1.minute)
      result = Rails.cache.read("health_check")
      response_time = ((Time.current - start_time) * 1000).round(2)
      
      if result == "ok"
        { status: "healthy", response_time_ms: response_time }
      else
        { status: "unhealthy", error: "Cache read/write failed" }
      end
    rescue => e
      { status: "unhealthy", error: e.message }
    end
  end

  # OpenAI API 상태 확인
  def check_openai_health
    begin
      # 간단한 임베딩 요청으로 API 상태 확인
      client = OpenAI::Client.new(
        access_token: Rails.application.credentials.openai_api_key || ENV["OPENAI_API_KEY"]
      )
      
      start_time = Time.current
      response = client.embeddings(
        parameters: {
          model: "text-embedding-3-small",
          input: "health check"
        }
      )
      response_time = ((Time.current - start_time) * 1000).round(2)
      
      if response.dig("data", 0, "embedding")
        { status: "healthy", response_time_ms: response_time }
      else
        { status: "unhealthy", error: "Invalid API response" }
      end
    rescue => e
      { status: "unhealthy", error: e.message }
    end
  end

  # pgvector 상태 확인
  def check_pgvector_health
    begin
      start_time = Time.current
      result = ActiveRecord::Base.connection.execute("SELECT extname FROM pg_extension WHERE extname = 'vector'")
      response_time = ((Time.current - start_time) * 1000).round(2)
      
      if result.any?
        { status: "healthy", response_time_ms: response_time }
      else
        { status: "unhealthy", error: "pgvector extension not found" }
      end
    rescue => e
      { status: "unhealthy", error: e.message }
    end
  end
