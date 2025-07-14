# frozen_string_literal: true

# pgvector를 사용한 벡터 유사도 검색 서비스
class VectorSearchService
  attr_reader :query, :options, :results

  DEFAULT_OPTIONS = {
    limit: 10,
    similarity_threshold: 0.7,
    include_context: true,
    boost_recent: false,
    filter_active_only: true
  }.freeze

  def initialize(query, options = {})
    @query = query.to_s.strip
    @options = DEFAULT_OPTIONS.merge(options)
    @results = []
  end

  # 메인 검색 메서드
  def search
    return [] if @query.blank?

    Rails.logger.info "Vector search query: #{@query}"
    
    begin
      # 1. 쿼리 임베딩 생성 (개선된 파이프라인 사용)
      embedding_result = QuestionEmbeddingService.generate_embedding(@query)
      return [] unless embedding_result
      
      query_embedding = embedding_result[:embedding]
      @preprocessed_query = embedding_result[:preprocessed_text]
      @query_metadata = {
        token_count: embedding_result[:token_count],
        original_question: embedding_result[:original_question]
      }
      
      # 2. 벡터 유사도 검색 실행 (최적화된 검색 사용)
      @results = perform_optimized_vector_search(query_embedding)
      
      # 3. 결과 후처리
      @results = post_process_results(@results)
      
      Rails.logger.info "Vector search completed: #{@results.size} results found"
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

    Rails.logger.info "Hybrid search query: #{@query}"
    
    begin
      # 1. 벡터 검색 결과
      vector_results = search
      
      # 2. 키워드 검색 결과
      keyword_results = perform_keyword_search(@query)
      
      # 3. 결과 병합 및 재랭킹
      merged_results = merge_and_rerank(vector_results, keyword_results)
      
      Rails.logger.info "Hybrid search completed: #{merged_results.size} results found"
      merged_results
      
    rescue => e
      Rails.logger.error "Hybrid search failed: #{e.message}"
      []
    end
  end

  # 유사 조문 검색 (특정 조문과 유사한 조문 찾기)
  def find_similar_articles(article_id, limit: 5)
    article = Article.find(article_id)
    
    return [] unless article.embedding.present?
    
    Rails.logger.info "Finding similar articles to Article #{article_id}"
    
    similar_articles = Article.joins(:regulation)
                             .where.not(id: article_id)
                             .where.not(embedding: nil)
                             .where(is_active: true)
                             .select(
                               'articles.*, regulations.title as regulation_title, ' \
                               'regulations.regulation_code, ' \
                               '(articles.embedding <=> ?) as similarity'
                             )
                             .order('similarity ASC')
                             .limit(limit)
                             .load
    
    # 유사도 점수를 0-1 범위로 변환 (거리 -> 유사도)
    similar_articles.each do |similar_article|
      distance = similar_article.similarity.to_f
      similar_article.define_singleton_method(:similarity_score) do
        [0, 1 - distance].max.round(4)
      end
    end
    
    similar_articles
  end

  # 검색 통계 정보
  def search_stats
    {
      query: @query,
      total_results: @results.size,
      avg_similarity: calculate_average_similarity,
      search_time: @search_time,
      options: @options
    }
  end

  private

  def generate_query_embedding(query)
    # 쿼리 텍스트를 임베딩으로 변환
    response = openai_client.embeddings(
      parameters: {
        model: 'text-embedding-3-small',
        input: query
      }
    )
    
    embedding = response.dig('data', 0, 'embedding')
    
    unless embedding&.is_a?(Array) && embedding.length == 1536
      raise "Invalid embedding response for query: #{query}"
    end
    
    embedding
  end

  def perform_vector_search(query_embedding)
    start_time = Time.current
    
    # pgvector를 사용한 코사인 유사도 검색
    base_query = Article.joins(:regulation)
                        .where.not(embedding: nil)
    
    # 활성 조문만 검색
    base_query = base_query.where(is_active: true) if @options[:filter_active_only]
    
    # 유사도 계산 및 정렬
    results = base_query.select(
                'articles.*, regulations.title as regulation_title, ' \
                'regulations.regulation_code, ' \
                'chapters.title as chapter_title, ' \
                'editions.title as edition_title, ' \
                '(1 - (articles.embedding <=> ?)) as similarity_score'
              )
              .joins(regulation: { chapter: :edition })
              .where('(1 - (articles.embedding <=> ?)) >= ?', 
                     query_embedding, @options[:similarity_threshold])
              .order('similarity_score DESC')
              .limit(@options[:limit])
              .load
    
    @search_time = Time.current - start_time
    results
  end

  def perform_keyword_search(query)
    # PostgreSQL의 전문 검색 기능 사용
    search_terms = query.split.map { |term| "%#{term}%" }
    
    Article.joins(:regulation)
           .where(is_active: true)
           .where(
             search_terms.map { 'articles.content ILIKE ? OR articles.title ILIKE ?' }.join(' OR '),
             *search_terms.flat_map { |term| [term, term] }
           )
           .select('articles.*, regulations.title as regulation_title, regulations.regulation_code')
           .limit(@options[:limit])
  end

  def merge_and_rerank(vector_results, keyword_results)
    # 벡터 검색과 키워드 검색 결과를 병합
    all_results = {}
    
    # 벡터 검색 결과 (가중치 0.7)
    vector_results.each_with_index do |article, index|
      score = (article.similarity_score || 0) * 0.7
      all_results[article.id] = {
        article: article,
        vector_score: article.similarity_score || 0,
        keyword_score: 0,
        combined_score: score,
        vector_rank: index + 1,
        keyword_rank: nil
      }
    end
    
    # 키워드 검색 결과 (가중치 0.3)
    keyword_results.each_with_index do |article, index|
      keyword_score = (1.0 - (index.to_f / keyword_results.size)) * 0.3
      
      if all_results[article.id]
        all_results[article.id][:keyword_score] = keyword_score
        all_results[article.id][:combined_score] += keyword_score
        all_results[article.id][:keyword_rank] = index + 1
      else
        all_results[article.id] = {
          article: article,
          vector_score: 0,
          keyword_score: keyword_score,
          combined_score: keyword_score,
          vector_rank: nil,
          keyword_rank: index + 1
        }
      end
    end
    
    # 결합 점수로 정렬
    sorted_results = all_results.values
                                .sort_by { |result| -result[:combined_score] }
                                .first(@options[:limit])
    
    # Article 객체에 점수 정보 추가
    sorted_results.map do |result|
      article = result[:article]
      article.define_singleton_method(:vector_score) { result[:vector_score] }
      article.define_singleton_method(:keyword_score) { result[:keyword_score] }
      article.define_singleton_method(:combined_score) { result[:combined_score] }
      article.define_singleton_method(:vector_rank) { result[:vector_rank] }
      article.define_singleton_method(:keyword_rank) { result[:keyword_rank] }
      article
    end
  end

  def post_process_results(results)
    processed_results = results.dup
    
    # 최근 업데이트된 조문에 부스트 적용
    if @options[:boost_recent]
      processed_results = apply_recency_boost(processed_results)
    end
    
    # 컨텍스트 정보 추가
    if @options[:include_context]
      processed_results = add_context_info(processed_results)
    end
    
    processed_results
  end

  def apply_recency_boost(results)
    # 최근 30일 내 업데이트된 조문에 10% 부스트
    recent_threshold = 30.days.ago
    
    results.each do |article|
      if article.updated_at > recent_threshold
        current_score = article.similarity_score || 0
        boosted_score = [current_score * 1.1, 1.0].min
        article.define_singleton_method(:similarity_score) { boosted_score }
      end
    end
    
    results.sort_by { |article| -(article.similarity_score || 0) }
  end

  def add_context_info(results)
    results.each do |article|
      # 계층 구조 정보 추가
      context_path = []
      
      if article.respond_to?(:edition_title) && article.edition_title.present?
        context_path << article.edition_title
      end
      
      if article.respond_to?(:chapter_title) && article.chapter_title.present?
        context_path << article.chapter_title
      end
      
      if article.respond_to?(:regulation_title) && article.regulation_title.present?
        context_path << article.regulation_title
      end
      
      article.define_singleton_method(:context_path) { context_path.join(' > ') }
      
      # 하이라이트된 내용 생성
      highlighted_content = highlight_query_terms(article.content, @query)
      article.define_singleton_method(:highlighted_content) { highlighted_content }
    end
    
    results
  end

  def highlight_query_terms(content, query)
    return content if query.blank? || content.blank?
    
    # 쿼리 단어들로 하이라이트 적용
    highlighted = content.dup
    query.split.each do |term|
      highlighted.gsub!(/(#{Regexp.escape(term)})/i, '<mark>\1</mark>')
    end
    
    highlighted
  end

  def calculate_average_similarity
    return 0.0 if @results.empty?
    
    similarities = @results.map { |r| r.similarity_score || 0 }
    (similarities.sum / similarities.size).round(4)
  end

  def openai_client
    @openai_client ||= OpenAI::Client.new(
      access_token: Rails.application.credentials.openai_api_key || ENV['OPENAI_API_KEY'],
      log_errors: true
    )
  end
end
  # 최적화된 벡터 유사도 검색 실행
  def perform_optimized_vector_search(query_embedding)
    # PgvectorOptimizer를 사용한 최적화된 검색
    optimizer_options = {
      limit: @options[:limit],
      similarity_threshold: @options[:similarity_threshold],
      distance_function: determine_distance_function,
      use_ivfflat: should_use_ivfflat?,
      ef_search: determine_ef_search
    }
    
    results = PgvectorOptimizer.search(
      embedding: query_embedding,
      **optimizer_options
    )
    
    # 결과를 표준 형식으로 변환
    formatted_results = results.map { |result| format_optimized_result(result) }
    
    Rails.logger.info "Optimized vector search found #{formatted_results.length} results"
    formatted_results
  end

  # 거리 함수 결정
  def determine_distance_function
    # 기본적으로 cosine 사용, 옵션으로 변경 가능
    @options[:distance_function] || "cosine"
  end

  # IVFFlat 사용 여부 결정
  def should_use_ivfflat?
    # 대용량 데이터나 높은 처리량이 필요한 경우 IVFFlat 사용
    article_count = Article.where.not(embedding: nil).count
    @options[:use_ivfflat] || (article_count > 10000)
  end

  # ef_search 파라미터 결정
  def determine_ef_search
    # 정확도와 속도의 균형을 위한 동적 설정
    case @options[:limit]
    when 1..5
      16  # 적은 결과 요청 시 낮은 ef_search
    when 6..20
      40  # 중간 결과 요청 시 기본값
    else
      64  # 많은 결과 요청 시 높은 ef_search
    end
  end

  # 최적화된 결과 포맷팅
  def format_optimized_result(result)
    {
      id: result[:id],
      title: result[:title],
      content: result[:content],
      number: result[:number],
      regulation_id: result[:regulation_id],
      regulation_title: result[:regulation_title],
      regulation_code: result[:regulation_code],
      distance: result[:distance],
      similarity: result[:similarity],
      full_context: build_full_context(result)
    }
  end

  # 전체 컨텍스트 구성
  def build_full_context(result)
    "#{result[:regulation_title]} (#{result[:regulation_code]}) > 제#{result[:number]}조 #{result[:title]}"
  end
