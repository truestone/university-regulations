# frozen_string_literal: true

class OptimizePgvectorIndexes < ActiveRecord::Migration[8.0]
  def up
    # 기존 HNSW 인덱스 제거 (더 최적화된 버전으로 교체)
    remove_index :articles, :embedding, if_exists: true
    remove_index :search_queries, :embedding, if_exists: true

    # Articles 테이블용 최적화된 HNSW 인덱스
    # m=16, ef_construction=64로 설정하여 검색 품질과 속도 균형
    add_index :articles, :embedding, 
              using: :hnsw, 
              opclass: :vector_cosine_ops,
              with: 'm=16, ef_construction=64',
              name: 'idx_articles_embedding_hnsw_optimized'

    # 대안으로 IVFFlat 인덱스도 생성 (대용량 데이터용)
    # lists=100으로 설정 (일반적으로 행 수의 sqrt 정도)
    add_index :articles, :embedding,
              using: :ivfflat,
              opclass: :vector_cosine_ops,
              with: 'lists=100',
              name: 'idx_articles_embedding_ivfflat'

    # SearchQueries 테이블용 HNSW 인덱스
    add_index :search_queries, :embedding,
              using: :hnsw,
              opclass: :vector_cosine_ops,
              with: 'm=16, ef_construction=64',
              name: 'idx_search_queries_embedding_hnsw'

    # L2 거리용 인덱스도 추가
    add_index :articles, :embedding,
              using: :hnsw,
              opclass: :vector_l2_ops,
              with: 'm=16, ef_construction=64',
              name: 'idx_articles_embedding_l2'

    # 내적용 인덱스
    add_index :articles, :embedding,
              using: :hnsw,
              opclass: :vector_ip_ops,
              with: 'm=16, ef_construction=64',
              name: 'idx_articles_embedding_ip'

    # 복합 인덱스 (is_active와 함께)
    execute <<-SQL
      CREATE INDEX CONCURRENTLY idx_articles_active_embedding 
      ON articles (is_active) 
      WHERE is_active = true AND embedding IS NOT NULL;
    SQL

    # 통계 업데이트
    execute "ANALYZE articles;"
    execute "ANALYZE search_queries;"
  end

  def down
    # 최적화된 인덱스들 제거
    remove_index :articles, name: 'idx_articles_embedding_hnsw_optimized', if_exists: true
    remove_index :articles, name: 'idx_articles_embedding_ivfflat', if_exists: true
    remove_index :articles, name: 'idx_articles_embedding_l2', if_exists: true
    remove_index :articles, name: 'idx_articles_embedding_ip', if_exists: true
    remove_index :articles, name: 'idx_articles_active_embedding', if_exists: true
    remove_index :search_queries, name: 'idx_search_queries_embedding_hnsw', if_exists: true

    # 기본 인덱스 복원
    add_index :articles, :embedding, using: :hnsw, opclass: :vector_cosine_ops
    add_index :search_queries, :embedding, using: :hnsw, opclass: :vector_cosine_ops
  end
end