# frozen_string_literal: true

# 검색 쿼리 로그 및 분석을 위한 모델
class SearchQuery < ApplicationRecord
  validates :query_text, presence: true
  validates :response_time_ms, presence: true, numericality: { greater_than: 0 }
  validates :results_count, presence: true, numericality: { greater_than_or_equal_to: 0 }

  scope :recent, -> { where('created_at > ?', 1.week.ago) }
  scope :successful, -> { where.not(error_message: nil) }
  scope :failed, -> { where.not(error_message: nil) }

  # 검색 쿼리 로깅
  def self.log_search(query_text:, embedding:, results_count:, response_time_ms:, metadata: {}, error_message: nil)
    create!(
      query_text: query_text,
      embedding: embedding,
      results_count: results_count,
      response_time_ms: response_time_ms,
      metadata: metadata,
      error_message: error_message
    )
  rescue => e
    Rails.logger.error "Failed to log search query: #{e.message}"
  end

  # 유사한 검색 쿼리 찾기
  def similar_queries(limit: 5)
    return SearchQuery.none unless embedding.present?

    SearchQuery.where.not(id: id)
              .order(Arel.sql("embedding <=> '#{embedding.to_s}'"))
              .limit(limit)
  end

  # 검색 성능 통계
  def self.performance_stats(period: 1.week)
    queries = where('created_at > ?', period.ago)
    
    {
      total_queries: queries.count,
      successful_queries: queries.where(error_message: nil).count,
      failed_queries: queries.where.not(error_message: nil).count,
      avg_response_time: queries.average(:response_time_ms)&.round(2),
      avg_results_count: queries.average(:results_count)&.round(2),
      most_common_errors: queries.where.not(error_message: nil)
                                 .group(:error_message)
                                 .count
                                 .sort_by { |_, count| -count }
                                 .first(5)
    }
  end

  # 인기 검색어 분석
  def self.popular_queries(limit: 10, period: 1.week)
    where('created_at > ?', period.ago)
      .group(:query_text)
      .count
      .sort_by { |_, count| -count }
      .first(limit)
      .map { |query, count| { query: query, count: count } }
  end
end