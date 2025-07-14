# frozen_string_literal: true

class Article < ApplicationRecord
  belongs_to :regulation
  has_many :clauses, dependent: :destroy

  validates :title, presence: true
  validates :content, presence: true
  validates :sort_order, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :embedding, embedding: true, allow_nil: true

  scope :ordered, -> { order(:sort_order) }
  default_scope { ordered }

  # 임베딩 업데이트가 필요한지 확인
  def needs_embedding_update?
    embedding.nil? || 
    embedding_updated_at.nil? || 
    updated_at > embedding_updated_at
  end

  # 전체 컨텍스트 정보 반환
  def full_context
    context_parts = []
    
    # 편 정보
    if regulation&.chapter&.edition
      edition = regulation.chapter.edition
      context_parts << "편: #{edition.title}"
    end
    
    # 장 정보
    if regulation&.chapter
      chapter = regulation.chapter
      context_parts << "장: #{chapter.title}"
    end
    
    # 규정 정보
    if regulation
      context_parts << "규정: #{regulation.title} (#{regulation.regulation_code})"
    end
    
    # 조문 정보
    context_parts << "조문: 제#{number}조 (#{title})"
    
    context_parts.join(' > ')
  end

  # 임베딩 생성 작업을 큐에 추가
  after_commit :enqueue_embedding_job, on: [:create, :update]

  private

  def enqueue_embedding_job
    # 임베딩 업데이트가 필요한 경우에만 작업 큐에 추가
    if needs_embedding_update?
      EmbeddingJob.perform_async(id)
    end
  end
end