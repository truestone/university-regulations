# frozen_string_literal: true

# GPT-4를 사용한 RAG 답변 생성 서비스
class GptAnswerService
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :question, :string
  attribute :search_results, :string
  attribute :model, :string, default: 'gpt-4'
  attribute :temperature, :float, default: 0.3
  attribute :max_tokens, :integer, default: 1000
  attribute :response_format, :string, default: 'detailed'

  validates :question, presence: true
  validates :search_results, presence: true
  validates :model, inclusion: { in: %w[gpt-4 gpt-4-turbo gpt-3.5-turbo] }
  validates :temperature, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 2 }
  validates :max_tokens, numericality: { greater_than: 0, less_than_or_equal_to: 4000 }

  # 메인 답변 생성 메서드
  def self.generate_answer(question:, search_results:, **options)
    service = new(question: question, search_results: search_results, **options)
    service.generate
  end

  def generate
    return nil unless valid?

    Rails.logger.info "Generating GPT answer for question: #{question.truncate(100)}"
    
    start_time = Time.current
    
    begin
      # 1. RAG 프롬프트 생성
      prompt_data = generate_rag_prompt
      
      # 2. GPT-4 API 호출
      response = call_openai_api(prompt_data)
      
      # 3. 응답 처리 및 검증
      processed_response = process_response(response)
      
      # 4. 성능 메트릭 수집
      execution_time = ((Time.current - start_time) * 1000).round(2)
      
      # 5. 결과 구성
      build_final_result(processed_response, prompt_data, execution_time)
      
    rescue => e
      Rails.logger.error "GPT answer generation failed: #{e.message}"
      handle_error(e, start_time)
    end
  end

  private

  # RAG 프롬프트 생성
  def generate_rag_prompt
    RagPromptService.generate_prompt(
      question: question,
      search_results: search_results,
      response_format: response_format,
      safety_mode: true,
      max_context_tokens: calculate_max_context_tokens
    )
  end

  # 최대 컨텍스트 토큰 계산
  def calculate_max_context_tokens
    # 전체 토큰에서 시스템 프롬프트, 질문, 응답용 토큰을 제외
    total_available = model_max_tokens - max_tokens - 500 # 500은 시스템 프롬프트 + 오버헤드
    [total_available, 3000].min # 최대 3000 토큰으로 제한
  end

  # 모델별 최대 토큰 수
  def model_max_tokens
    case model
    when 'gpt-4'
      8192
    when 'gpt-4-turbo'
      128000
    when 'gpt-3.5-turbo'
      4096
    else
      4096
    end
  end

  # OpenAI API 호출
  def call_openai_api(prompt_data)
    messages = [
      {
        role: 'system',
        content: prompt_data[:system_prompt]
      },
      {
        role: 'user',
        content: prompt_data[:user_prompt]
      }
    ]

    response = openai_client.chat(
      parameters: {
        model: model,
        messages: messages,
        temperature: temperature,
        max_tokens: max_tokens,
        top_p: 0.9,
        frequency_penalty: 0.1,
        presence_penalty: 0.1
      }
    )

    response
  end

  # 응답 처리 및 검증
  def process_response(response)
    content = response.dig('choices', 0, 'message', 'content')
    
    unless content.present?
      raise "Empty response from OpenAI API"
    end

    # 응답 품질 검증
    validate_response_quality(content)
    
    # 후처리
    post_process_content(content)
  end

  # 응답 품질 검증
  def validate_response_quality(content)
    # 최소 길이 검증
    if content.length < 50
      Rails.logger.warn "GPT response too short: #{content.length} characters"
    end

    # 금지된 표현 검증
    forbidden_phrases = [
      '저는 AI입니다',
      '확실하지 않습니다',
      '정확한 답변을 드릴 수 없습니다'
    ]

    forbidden_phrases.each do |phrase|
      if content.include?(phrase)
        Rails.logger.warn "GPT response contains forbidden phrase: #{phrase}"
      end
    end

    # 규정 참조 확인
    unless content.match?(/제\d+조|규정|조문/)
      Rails.logger.warn "GPT response lacks regulation references"
    end
  end

  # 응답 후처리
  def post_process_content(content)
    # 불필요한 접두사 제거
    content = content.gsub(/^(답변:|Answer:|응답:)\s*/, '')
    
    # 마크다운 형식 정리
    content = clean_markdown(content)
    
    # 최종 검증
    content.strip
  end

  # 마크다운 정리
  def clean_markdown(content)
    # 과도한 강조 제거
    content = content.gsub(/\*{3,}/, '**')
    
    # 연속된 줄바꿈 정리
    content = content.gsub(/\n{3,}/, "\n\n")
    
    content
  end

  # 최종 결과 구성
  def build_final_result(processed_response, prompt_data, execution_time)
    {
      answer: processed_response,
      sources: extract_sources_from_search_results,
      metadata: {
        model: model,
        temperature: temperature,
        max_tokens: max_tokens,
        execution_time_ms: execution_time,
        prompt_tokens: prompt_data[:metadata][:total_prompt_tokens],
        response_tokens: estimate_tokens(processed_response),
        context_used: prompt_data[:context],
        quality_score: calculate_quality_score(processed_response, prompt_data),
        generated_at: Time.current
      }
    }
  end

  # 검색 결과에서 소스 추출
  def extract_sources_from_search_results
    results = search_results.is_a?(String) ? JSON.parse(search_results) : search_results
    
    results.map do |result|
      {
        id: result['id'] || result[:id],
        title: result['title'] || result[:title],
        regulation_title: result['regulation_title'] || result[:regulation_title],
        regulation_code: result['regulation_code'] || result[:regulation_code],
        number: result['number'] || result[:number],
        similarity: result['similarity'] || result[:similarity]
      }
    end.first(5) # 최대 5개 소스만 포함
  end

  # 품질 점수 계산
  def calculate_quality_score(response, prompt_data)
    score = 0
    
    # 길이 점수 (적절한 길이)
    length_score = case response.length
                  when 100..500 then 20
                  when 501..1000 then 25
                  when 1001..2000 then 20
                  else 10
                  end
    score += length_score
    
    # 규정 참조 점수
    regulation_references = response.scan(/제\d+조/).length
    score += [regulation_references * 5, 20].min
    
    # 구조화 점수
    if response.include?('**') || response.include?('##')
      score += 15
    end
    
    # 컨텍스트 활용 점수
    context_score = prompt_data[:context][:used_results] * 2
    score += [context_score, 20].min
    
    # 유사도 점수
    max_similarity = prompt_data[:context][:max_similarity] || 0
    score += (max_similarity * 20).round
    
    [score, 100].min
  end

  # 토큰 수 추정
  def estimate_tokens(text)
    # 간단한 토큰 수 추정
    korean_chars = text.scan(/[가-힣]/).length
    english_chars = text.scan(/[a-zA-Z]/).length
    other_chars = text.length - korean_chars - english_chars
    
    (korean_chars + (english_chars / 4.0) + (other_chars / 2.0)).ceil
  end

  # 에러 처리
  def handle_error(error, start_time)
    execution_time = ((Time.current - start_time) * 1000).round(2)
    
    error_response = {
      answer: "죄송합니다. 현재 시스템에 일시적인 문제가 발생했습니다. 잠시 후 다시 시도해 주세요.",
      sources: extract_sources_from_search_results,
      error: {
        message: error.message,
        type: error.class.name,
        execution_time_ms: execution_time,
        occurred_at: Time.current
      }
    }

    # 에러 로깅
    Rails.logger.error "GPT Answer Service Error: #{error.message}"
    Rails.logger.error error.backtrace.join("\n") if Rails.env.development?

    error_response
  end

  # OpenAI 클라이언트
  def openai_client
    @openai_client ||= OpenAI::Client.new(
      access_token: Rails.application.credentials.openai_api_key || ENV['OPENAI_API_KEY'],
      log_errors: true
    )
  end

  # A/B 테스트용 답변 생성
  def self.generate_ab_test_answers(question:, search_results:, **options)
    # 두 가지 다른 설정으로 답변 생성
    variant_a = generate_answer(
      question: question,
      search_results: search_results,
      temperature: 0.3,
      response_format: 'detailed',
      **options
    )

    variant_b = generate_answer(
      question: question,
      search_results: search_results,
      temperature: 0.7,
      response_format: 'structured',
      **options
    )

    {
      variant_a: variant_a,
      variant_b: variant_b,
      test_metadata: {
        question: question,
        generated_at: Time.current,
        test_id: SecureRandom.uuid
      }
    }
  end
end