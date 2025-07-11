# frozen_string_literal: true

# Article 임베딩 생성을 위한 Sidekiq 워커
class EmbeddingJob
  include Sidekiq::Worker
  
  sidekiq_options queue: :embedding, retry: 5, backtrace: true

  # Article ID를 받아 OpenAI API로 임베딩 생성 후 저장
  def perform(article_id)
    article = Article.find(article_id)
    
    # 이미 최신 임베딩이 있는 경우 스킵
    return if skip_embedding_generation?(article)
    
    Rails.logger.info "Generating embedding for Article #{article_id}"
    
    begin
      # 임베딩 생성
      embedding_vector = generate_embedding(article)
      
      # 데이터베이스에 저장
      article.update!(
        embedding: embedding_vector,
        embedding_updated_at: Time.current
      )
      
      Rails.logger.info "Successfully generated embedding for Article #{article_id}"
      
    rescue => e
      Rails.logger.error "Failed to generate embedding for Article #{article_id}: #{e.message}"
      raise e # Sidekiq 재시도를 위해 예외 재발생
    end
  end

  private

  def skip_embedding_generation?(article)
    # 임베딩이 이미 있고, 최신 상태인 경우 스킵
    article.embedding_updated_at.present? && 
    article.updated_at <= article.embedding_updated_at
  end

  def generate_embedding(article)
    # 컨텍스트와 내용을 결합한 프롬프트 생성
    prompt = build_prompt(article)
    
    # OpenAI API 호출
    response = openai_client.embeddings(
      parameters: {
        model: embedding_model,
        input: prompt
      }
    )
    
    # 임베딩 벡터 추출
    embedding = response.dig('data', 0, 'embedding')
    
    unless embedding&.is_a?(Array) && embedding.length == 1536
      raise "Invalid embedding response: expected array of length 1536, got #{embedding&.class} with length #{embedding&.length}"
    end
    
    embedding
  end

  def build_prompt(article)
    # Article의 전체 컨텍스트 구성
    context_parts = []
    
    # 편 정보
    if article.regulation&.chapter&.edition
      edition = article.regulation.chapter.edition
      context_parts << "편: #{edition.title}"
    end
    
    # 장 정보
    if article.regulation&.chapter
      chapter = article.regulation.chapter
      context_parts << "장: #{chapter.title}"
    end
    
    # 규정 정보
    if article.regulation
      regulation = article.regulation
      context_parts << "규정: #{regulation.title} (#{regulation.regulation_code})"
    end
    
    # 조문 정보
    context_parts << "조문: 제#{article.number}조 (#{article.title})"
    
    # 최종 프롬프트 구성
    context = context_parts.join(' > ')
    "#{context}\n\n#{article.content}"
  end

  def openai_client
    @openai_client ||= OpenAI::Client.new(
      access_token: Rails.application.credentials.openai_api_key || ENV['OPENAI_API_KEY'],
      log_errors: true
    )
  end

  def embedding_model
    # OpenAI의 최신 임베딩 모델 사용
    'text-embedding-3-small'
  end
end