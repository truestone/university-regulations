# frozen_string_literal: true

# pgvector 검색 쿼리 최적화 서비스
class PgvectorOptimizer
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :embedding, :string
  attribute :limit, :integer, default: 10
  attribute :similarity_threshold, :float, default: 0.7
  attribute :distance_function, :string, default: 'cosine'
  attribute :use_ivfflat, :boolean, default: false
  attribute :ef_search, :integer, default: 40

  validates :embedding, presence: true
  validates :limit, presence: true, numericality: { greater_than: 0, less_than_or_equal_to: 100 }
  validates :similarity_threshold, presence: true, numericality: { greater_than: 0, less_than_or_equal_to: 1 }
  validates :distance_function, inclusion: { in: %w[cosine l2 inner_product] }

  # 최적화된 벡터 검색 실행
  def self.search(embedding:, **options)
    optimizer = new(embedding: embedding, **options)
    optimizer.execute_search
  end

  def execute_search
    return [] unless valid?

    start_time = Time.current
    
    begin
      # 1. 최적 쿼리 선택
      query_sql = build_optimized_query
      
      # 2. 쿼리 실행
      results = execute_query(query_sql)
      
      # 3. 성능 메트릭 수집
      execution_time = ((Time.current - start_time) * 1000).round(2)
      log_performance_metrics(results.length, execution_time, query_sql)
      
      results
      
    rescue => e
      Rails.logger.error "PgvectorOptimizer search failed: #{e.message}"
      raise e
    end
  end

  # 쿼리 성능 분석
  def analyze_query_performance
    return unless valid?

    query_sql = build_optimized_query
    explain_sql = "EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON) #{query_sql}"
    
    result = ActiveRecord::Base.connection.execute(explain_sql)
    analysis = JSON.parse(result.first['QUERY PLAN'])
    
    extract_performance_metrics(analysis)
  end

  private

  # 최적화된 쿼리 빌드
  def build_optimized_query
    case distance_function
    when 'cosine'
      build_cosine_query
    when 'l2'
      build_l2_query
    when 'inner_product'
      build_inner_product_query
    else
      build_cosine_query # 기본값
    end
  end

  # 코사인 거리 쿼리 (기본)
  def build_cosine_query
    if use_ivfflat
      build_ivfflat_cosine_query
    else
      build_hnsw_cosine_query
    end
  end

  # HNSW 인덱스 사용 코사인 쿼리
  def build_hnsw_cosine_query
    sanitized_embedding = ActiveRecord::Base.connection.quote(embedding.to_s)
    threshold = 1 - similarity_threshold # 코사인 거리는 1 - 유사도
    
    <<~SQL
      SELECT 
        articles.id,
        articles.title,
        articles.content,
        articles.number,
        articles.regulation_id,
        regulations.title as regulation_title,
        regulations.regulation_code,
        (articles.embedding <=> #{sanitized_embedding}) AS distance,
        (1 - (articles.embedding <=> #{sanitized_embedding})) AS similarity
      FROM articles
      INNER JOIN regulations ON articles.regulation_id = regulations.id
      WHERE articles.embedding IS NOT NULL
        AND articles.is_active = true
        AND (articles.embedding <=> #{sanitized_embedding}) < #{threshold}
      ORDER BY articles.embedding <=> #{sanitized_embedding}
      LIMIT #{limit}
    SQL
  end

  # IVFFlat 인덱스 사용 코사인 쿼리
  def build_ivfflat_cosine_query
    sanitized_embedding = ActiveRecord::Base.connection.quote(embedding.to_s)
    
    # IVFFlat은 근사 검색이므로 더 많은 후보를 가져온 후 필터링
    candidate_limit = [limit * 3, 100].min
    threshold = 1 - similarity_threshold
    
    <<~SQL
      WITH candidates AS (
        SELECT 
          articles.id,
          articles.title,
          articles.content,
          articles.number,
          articles.regulation_id,
          regulations.title as regulation_title,
          regulations.regulation_code,
          (articles.embedding <=> #{sanitized_embedding}) AS distance
        FROM articles
        INNER JOIN regulations ON articles.regulation_id = regulations.id
        WHERE articles.embedding IS NOT NULL
          AND articles.is_active = true
        ORDER BY articles.embedding <=> #{sanitized_embedding}
        LIMIT #{candidate_limit}
      )
      SELECT 
        *,
        (1 - distance) AS similarity
      FROM candidates
      WHERE distance < #{threshold}
      ORDER BY distance
      LIMIT #{limit}
    SQL
  end

  # L2 거리 쿼리
  def build_l2_query
    sanitized_embedding = ActiveRecord::Base.connection.quote(embedding.to_s)
    # L2 거리의 경우 임계값을 다르게 설정
    threshold = 2.0 - similarity_threshold
    
    <<~SQL
      SELECT 
        articles.id,
        articles.title,
        articles.content,
        articles.number,
        articles.regulation_id,
        regulations.title as regulation_title,
        regulations.regulation_code,
        (articles.embedding <-> #{sanitized_embedding}) AS distance,
        (2.0 - (articles.embedding <-> #{sanitized_embedding})) AS similarity
      FROM articles
      INNER JOIN regulations ON articles.regulation_id = regulations.id
      WHERE articles.embedding IS NOT NULL
        AND articles.is_active = true
        AND (articles.embedding <-> #{sanitized_embedding}) < #{threshold}
      ORDER BY articles.embedding <-> #{sanitized_embedding}
      LIMIT #{limit}
    SQL
  end

  # 내적 쿼리
  def build_inner_product_query
    sanitized_embedding = ActiveRecord::Base.connection.quote(embedding.to_s)
    # 내적의 경우 높은 값이 더 유사함
    threshold = similarity_threshold
    
    <<~SQL
      SELECT 
        articles.id,
        articles.title,
        articles.content,
        articles.number,
        articles.regulation_id,
        regulations.title as regulation_title,
        regulations.regulation_code,
        (articles.embedding <#> #{sanitized_embedding}) * -1 AS distance,
        (articles.embedding <#> #{sanitized_embedding}) * -1 AS similarity
      FROM articles
      INNER JOIN regulations ON articles.regulation_id = regulations.id
      WHERE articles.embedding IS NOT NULL
        AND articles.is_active = true
        AND (articles.embedding <#> #{sanitized_embedding}) * -1 > #{threshold}
      ORDER BY articles.embedding <#> #{sanitized_embedding}
      LIMIT #{limit}
    SQL
  end

  # 쿼리 실행
  def execute_query(sql)
    # ef_search 파라미터 설정 (HNSW 인덱스용)
    ActiveRecord::Base.connection.execute("SET hnsw.ef_search = #{ef_search}")
    
    result = ActiveRecord::Base.connection.execute(sql)
    
    result.map do |row|
      {
        id: row['id'],
        title: row['title'],
        content: row['content'],
        number: row['number'],
        regulation_id: row['regulation_id'],
        regulation_title: row['regulation_title'],
        regulation_code: row['regulation_code'],
        distance: row['distance'].to_f,
        similarity: row['similarity'].to_f
      }
    end
  end

  # 성능 메트릭 로깅
  def log_performance_metrics(result_count, execution_time, query_sql)
    Rails.logger.info "PgvectorOptimizer Performance:"
    Rails.logger.info "  - Results: #{result_count}"
    Rails.logger.info "  - Execution time: #{execution_time}ms"
    Rails.logger.info "  - Distance function: #{distance_function}"
    Rails.logger.info "  - Index type: #{use_ivfflat ? 'IVFFlat' : 'HNSW'}"
    Rails.logger.info "  - ef_search: #{ef_search}"
    Rails.logger.info "  - Similarity threshold: #{similarity_threshold}"
    
    # 성능 데이터를 별도 로그나 메트릭 시스템에 저장할 수 있음
    store_performance_metrics(result_count, execution_time)
  end

  # 성능 메트릭 저장
  def store_performance_metrics(result_count, execution_time)
    # Redis나 별도 테이블에 성능 데이터 저장
    Rails.cache.write(
      "pgvector_performance_#{Time.current.strftime('%Y%m%d_%H')}",
      {
        timestamp: Time.current,
        result_count: result_count,
        execution_time: execution_time,
        distance_function: distance_function,
        use_ivfflat: use_ivfflat,
        ef_search: ef_search,
        similarity_threshold: similarity_threshold
      },
      expires_in: 24.hours
    )
  end

  # 쿼리 성능 분석 결과 추출
  def extract_performance_metrics(explain_result)
    plan = explain_result.first['Plan']
    
    {
      execution_time: plan['Actual Total Time'],
      planning_time: explain_result.first['Planning Time'],
      execution_time_total: explain_result.first['Execution Time'],
      rows_returned: plan['Actual Rows'],
      index_used: extract_index_info(plan),
      buffers_hit: plan.dig('Buffers', 'Hit'),
      buffers_read: plan.dig('Buffers', 'Read'),
      node_type: plan['Node Type']
    }
  end

  # 인덱스 사용 정보 추출
  def extract_index_info(plan)
    if plan['Index Name']
      {
        name: plan['Index Name'],
        type: plan['Node Type'],
        condition: plan['Index Cond']
      }
    else
      nil
    end
  end

  # 최적 파라미터 추천
  def self.recommend_parameters(article_count:, query_frequency: :medium)
    case article_count
    when 0..1000
      {
        distance_function: 'cosine',
        use_ivfflat: false,
        ef_search: 40,
        similarity_threshold: 0.7
      }
    when 1001..10000
      {
        distance_function: 'cosine',
        use_ivfflat: false,
        ef_search: query_frequency == :high ? 20 : 40,
        similarity_threshold: 0.75
      }
    when 10001..100000
      {
        distance_function: 'cosine',
        use_ivfflat: query_frequency == :high,
        ef_search: query_frequency == :high ? 16 : 32,
        similarity_threshold: 0.8
      }
    else
      {
        distance_function: 'cosine',
        use_ivfflat: true,
        ef_search: 16,
        similarity_threshold: 0.8
      }
    end
  end
end