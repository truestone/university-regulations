# frozen_string_literal: true

# 개선된 pgvector를 사용한 벡터 유사도 검색 서비스
class VectorSearchService
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :query, :string
  attribute :options, :string, default: -> { {} }
  attribute :results, :string, default: -> { [] }
  attribute :search_stats, :string, default: -> { {} }

  DEFAULT_OPTIONS = {
    limit: 10,
    similarity_threshold: 0.7,
    include_context: true,
    boost_recent: false,
    filter_active_only: true,
    distance_function: 'cosine',
    use_optimizer: true
  }.freeze

  validates :query, presence: true, length: { minimum: 1, maximum: 1000 }

  def initialize(query, options = {})
    @query = query.to_s.strip
    @options = DEFAULT_OPTIONS.merge(options.symbolize_keys)
    @results = []
    @search_stats = {}
    @start_time = nil
  end

  # 메인 벡터 검색 메서드
  def search
    return [] if @query.blank?

    @start_time = Time.current
    Rails.logger.info "Vector search query: #{@query}"
    
    begin
      # 1. 쿼리 임베딩 생성
      embedding_result = generate_query_embedding
      return [] unless embedding_result

      query_embedding = embedding_result[:embedding]
      
      # 2. 벡터 검색 실행
      @results = if @options[:use_optimizer]
                   perform_optimized_vector_search(query_embedding)
                 else
                   perform_basic_vector_search(query_embedding)
                 end

      # 3. 결과 후처리
      @results = post_process_results(@results)
      
      # 4. 검색 통계 생성
      generate_search_stats(embedding_result)
      
      Rails.logger.info "Vector search completed: #{@results.size} results in #{execution_time}ms"
      @results
      
    rescue => e
      Rails.logger.error "Vector search failed: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      []
    end
  end

  # 하이브리드 검색 (벡터 + 키워드)
  def hybrid_search
    return [] if @query.blank?

    @start_time = Time.current
    Rails.logger.info "Hybrid search query: #{@query}"
    
    begin
      # 1. 벡터 검색 결과
      vector_results = search
      
      # 2. 키워드 검색 결과
      keyword_results = perform_keyword_search
      
      # 3. 결과 결합 및 중복 제거
      @results = combine_search_results(vector_results, keyword_results)
      
      # 4. 하이브리드 점수 계산
      @results = calculate_hybrid_scores(@results)
      
      # 5. 최종 정렬 및 제한
      @results = @results.sort_by { |r| -r[:combined_score] }
                        .first(@options[:limit])
      
      # 6. 검색 통계 업데이트
      update_hybrid_search_stats(vector_results.size, keyword_results.size)
      
      Rails.logger.info "Hybrid search completed: #{@results.size} results in #{execution_time}ms"
      @results
      
    rescue => e
      Rails.logger.error "Hybrid search failed: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      []
    end
  end

  # 유사한 조문 찾기
  def find_similar_articles(article_id, limit: 5)
    article = Article.find_by(id: article_id)
    return [] unless article&.embedding

    @start_time = Time.current
    Rails.logger.info "Finding similar articles for article #{article_id}"
    
    begin
      # 해당 조문의 임베딩을 사용하여 유사한 조문 검색
      similar_articles = if @options[:use_optimizer]
                          PgvectorOptimizer.search(
                            embedding: article.embedding,
                            limit: limit + 1, # 자기 자신 제외를 위해 +1
                            similarity_threshold: @options[:similarity_threshold],
                            distance_function: @options[:distance_function]
                          )
                        else
                          perform_basic_similarity_search(article.embedding, limit + 1)
                        end

      # 자기 자신 제외
      similar_articles = similar_articles.reject { |a| a.id == article.id }
                                        .first(limit)

      # 유사도 점수 추가
      similar_articles.each do |similar_article|
        similar_article.define_singleton_method(:similarity_score) do
          similar_article.try(:similarity) || 0.0
        end
      end

      Rails.logger.info "Found #{similar_articles.size} similar articles in #{execution_time}ms"
      similar_articles
      
    rescue => e
      Rails.logger.error "Similar articles search failed: #{e.message}"
      []
    end
  end

  # 검색 통계 반환
  def search_stats
    @search_stats
  end

  private

  # 쿼리 임베딩 생성
  def generate_query_embedding
    Rails.logger.debug "Generating embedding for query: #{@query.truncate(100)}"
    
    begin
      embedding_result = QuestionEmbeddingService.generate_embedding(@query, @options)
      
      unless embedding_result
        Rails.logger.error "Failed to generate embedding for query"
        return nil
      end

      Rails.logger.debug "Successfully generated embedding (#{embedding_result[:token_count]} tokens)"
      embedding_result
      
    rescue => e
      Rails.logger.error "Error generating embedding: #{e.message}"
      # 임베딩 생성 실패 시 키워드 검색으로 폴백
      Rails.logger.info "Falling back to keyword search"
      return nil
    end
  end

  # 최적화된 벡터 검색 실행
  def perform_optimized_vector_search(query_embedding)
    Rails.logger.debug "Performing optimized vector search"
    
    begin
      optimizer_options = {
        limit: @options[:limit],
        similarity_threshold: @options[:similarity_threshold],
        distance_function: @options[:distance_function],
        use_ivfflat: determine_ivfflat_usage,
        ef_search: determine_ef_search_value
      }

      raw_results = PgvectorOptimizer.search(
        embedding: query_embedding,
        **optimizer_options
      )

      # Article 객체로 변환하고 유사도 점수 추가
      format_vector_results(raw_results)
      
    rescue => e
      Rails.logger.error "Optimized vector search failed: #{e.message}"
      # 최적화된 검색 실패 시 기본 검색으로 폴백
      Rails.logger.info "Falling back to basic vector search"
      perform_basic_vector_search(query_embedding)
    end
  end

  # 기본 벡터 검색 실행
  def perform_basic_vector_search(query_embedding)
    Rails.logger.debug "Performing basic vector search"
    
    # 임베딩 배열을 PostgreSQL vector 형식으로 변환
    embedding_string = "[#{query_embedding.join(',')}]"
    
    # 기본 코사인 유사도 검색
    sql = <<~SQL
      SELECT articles.*, 
             regulations.title as regulation_title,
             regulations.regulation_code,
             (1 - (articles.embedding <=> ?::vector)) AS similarity
      FROM articles 
      INNER JOIN regulations ON articles.regulation_id = regulations.id
      WHERE articles.embedding IS NOT NULL
        AND articles.is_active = true
        AND (1 - (articles.embedding <=> ?::vector)) >= ?
      ORDER BY articles.embedding <=> ?::vector
      LIMIT ?
    SQL

    results = Article.find_by_sql([
      sql, 
      embedding_string, 
      embedding_string, 
      @options[:similarity_threshold], 
      embedding_string, 
      @options[:limit]
    ])

    format_basic_results(results)
  end

  # 키워드 검색 실행
  def perform_keyword_search
    Rails.logger.debug "Performing keyword search for hybrid"
    
    keywords = @query.split(/\s+/).map(&:strip).reject(&:empty?)
    return [] if keywords.empty?

    # 안전한 키워드 검색
    conditions = keywords.map do |keyword|
      sanitized = ActiveRecord::Base.connection.quote("%#{keyword}%")
      "(articles.content ILIKE #{sanitized} OR articles.title ILIKE #{sanitized} OR regulations.title ILIKE #{sanitized})"
    end.join(' OR ')

    articles = Article.joins(:regulation)
                     .where(conditions)
                     .where(is_active: true)
                     .limit(@options[:limit])
                     .includes(:regulation)

    format_keyword_results(articles)
  end

  # 기본 유사도 검색 (find_similar_articles용)
  def perform_basic_similarity_search(embedding, limit)
    embedding_string = "[#{embedding.join(',')}]"
    
    sql = <<~SQL
      SELECT articles.*, 
             regulations.title as regulation_title,
             regulations.regulation_code,
             (1 - (articles.embedding <=> ?::vector)) AS similarity
      FROM articles 
      INNER JOIN regulations ON articles.regulation_id = regulations.id
      WHERE articles.embedding IS NOT NULL
        AND articles.is_active = true
      ORDER BY articles.embedding <=> ?::vector
      LIMIT ?
    SQL

    Article.find_by_sql([sql, embedding_string, embedding_string, limit])
  end

  # 벡터 검색 결과 포맷팅
  def format_vector_results(raw_results)
    raw_results.map do |result|
      article = result.is_a?(Article) ? result : Article.find(result.id)
      similarity_score = result.try(:similarity) || result.try(:distance) || 0.0
      
      format_article_result(article, similarity_score, 'vector')
    end
  end

  # 기본 검색 결과 포맷팅
  def format_basic_results(results)
    results.map do |article|
      similarity_score = article.try(:similarity) || 0.0
      format_article_result(article, similarity_score, 'vector')
    end
  end

  # 키워드 검색 결과 포맷팅
  def format_keyword_results(articles)
    articles.map do |article|
      relevance_score = calculate_keyword_relevance(article)
      format_article_result(article, relevance_score, 'keyword')
    end
  end

  # 조문 결과 포맷팅
  def format_article_result(article, score, search_type)
    {
      id: article.id,
      regulation_title: article.regulation.title,
      regulation_code: article.regulation.regulation_code,
      article_number: article.number,
      article_title: article.title,
      content: truncate_content(article.content),
      full_context: article.full_context,
      search_type: search_type,
      similarity_score: search_type == 'vector' ? score.round(4) : nil,
      relevance_score: search_type == 'keyword' ? score.round(4) : nil,
      created_at: article.created_at,
      updated_at: article.updated_at
    }
  end

  # 검색 결과 결합
  def combine_search_results(vector_results, keyword_results)
    combined = []
    seen_ids = Set.new

    # 벡터 검색 결과 추가
    vector_results.each do |result|
      unless seen_ids.include?(result[:id])
        combined << result
        seen_ids << result[:id]
      end
    end

    # 키워드 검색 결과 추가 (중복 제거)
    keyword_results.each do |result|
      unless seen_ids.include?(result[:id])
        combined << result
        seen_ids << result[:id]
      end
    end

    combined
  end

  # 하이브리드 점수 계산
  def calculate_hybrid_scores(results)
    results.map do |result|
      vector_score = result[:similarity_score] || 0.0
      keyword_score = result[:relevance_score] || 0.0
      
      # 가중 평균 (벡터 70%, 키워드 30%)
      combined_score = (vector_score * 0.7) + (keyword_score * 0.3)
      
      result.merge(combined_score: combined_score.round(4))
    end
  end

  # 키워드 관련성 점수 계산
  def calculate_keyword_relevance(article)
    keywords = @query.downcase.split(/\s+/)
    content_lower = article.content.downcase
    title_lower = article.title.downcase
    
    # 키워드 매치 계산
    title_matches = keywords.count { |k| title_lower.include?(k) }
    content_matches = keywords.count { |k| content_lower.include?(k) }
    
    # 점수 계산 (제목 매치에 더 높은 가중치)
    title_score = (title_matches.to_f / keywords.size) * 0.6
    content_score = (content_matches.to_f / keywords.size) * 0.4
    
    (title_score + content_score).round(4)
  end

  # 결과 후처리
  def post_process_results(results)
    # 최근성 부스트 적용
    if @options[:boost_recent]
      results = apply_recency_boost(results)
    end

    # 컨텍스트 정보 포함
    if @options[:include_context]
      results = add_context_information(results)
    end

    # 활성 조문만 필터링
    if @options[:filter_active_only]
      results = results.select { |r| Article.find(r[:id]).is_active }
    end

    results
  end

  # 최근성 부스트 적용
  def apply_recency_boost(results)
    current_time = Time.current
    
    results.map do |result|
      article = Article.find(result[:id])
      days_old = (current_time - article.updated_at) / 1.day
      
      # 30일 이내 조문에 부스트 적용
      if days_old <= 30
        boost_factor = 1.0 + (0.1 * (30 - days_old) / 30)
        
        if result[:similarity_score]
          result[:similarity_score] = [result[:similarity_score] * boost_factor, 1.0].min
        end
        
        if result[:relevance_score]
          result[:relevance_score] = [result[:relevance_score] * boost_factor, 1.0].min
        end
      end
      
      result
    end
  end

  # 컨텍스트 정보 추가
  def add_context_information(results)
    results.map do |result|
      article = Article.find(result[:id])
      
      result.merge(
        chapter_title: article.regulation.chapter&.title,
        edition_title: article.regulation.chapter&.edition&.title,
        related_clauses_count: article.clauses.count
      )
    end
  end

  # 콘텐츠 자르기
  def truncate_content(content, length = 200)
    return content if content.length <= length
    content[0..length] + "..."
  end

  # IVFFLAT 사용 여부 결정
  def determine_ivfflat_usage
    # 대용량 데이터셋에서만 IVFFLAT 사용
    Article.where.not(embedding: nil).count > 10000
  end

  # ef_search 값 결정
  def determine_ef_search_value
    # 정확도와 성능의 균형
    case @options[:limit]
    when 1..10 then 40
    when 11..20 then 60
    else 80
    end
  end

  # 검색 통계 생성
  def generate_search_stats(embedding_result = nil)
    @search_stats = {
      query: @query,
      total_results: @results.size,
      avg_similarity: calculate_average_similarity,
      search_time: execution_time,
      options: @options.except(:embedding),
      embedding_info: embedding_result&.except(:embedding)
    }
  end

  # 하이브리드 검색 통계 업데이트
  def update_hybrid_search_stats(vector_count, keyword_count)
    @search_stats.merge!(
      search_type: 'hybrid',
      vector_results: vector_count,
      keyword_results: keyword_count,
      combination_ratio: calculate_combination_ratio(vector_count, keyword_count)
    )
  end

  # 평균 유사도 계산
  def calculate_average_similarity
    return 0.0 if @results.empty?
    
    scores = @results.map { |r| r[:similarity_score] || r[:relevance_score] || 0.0 }
    (scores.sum / scores.size).round(4)
  end

  # 결합 비율 계산
  def calculate_combination_ratio(vector_count, keyword_count)
    total = vector_count + keyword_count
    return { vector: 0.0, keyword: 0.0 } if total == 0
    
    {
      vector: (vector_count.to_f / total * 100).round(1),
      keyword: (keyword_count.to_f / total * 100).round(1)
    }
  end

  # 실행 시간 계산
  def execution_time
    return 0.0 unless @start_time
    ((Time.current - @start_time) * 1000).round(2)
  end
end