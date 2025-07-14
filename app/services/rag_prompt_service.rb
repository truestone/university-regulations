# frozen_string_literal: true

# RAG(Retrieval-Augmented Generation) 프롬프트 생성 서비스
class RagPromptService
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :question, :string
  attribute :search_results, :string
  attribute :max_context_tokens, :integer, default: 3000
  attribute :include_sources, :boolean, default: true
  attribute :safety_mode, :boolean, default: true
  attribute :response_format, :string, default: 'detailed'

  validates :question, presence: true, length: { minimum: 3, maximum: 500 }
  validates :search_results, presence: true
  validates :max_context_tokens, presence: true, numericality: { greater_than: 100, less_than_or_equal_to: 8000 }
  validates :response_format, inclusion: { in: %w[brief detailed structured] }

  # 메인 프롬프트 생성 메서드
  def self.generate_prompt(question:, search_results:, **options)
    service = new(question: question, search_results: search_results, **options)
    service.build_prompt
  end

  def build_prompt
    return nil unless valid?

    {
      system_prompt: build_system_prompt,
      user_prompt: build_user_prompt,
      context: build_context,
      metadata: build_metadata
    }
  end

  private

  # 시스템 프롬프트 구성
  def build_system_prompt
    base_prompt = <<~PROMPT
      당신은 대학교 규정 전문가입니다. 제공된 규정 내용을 바탕으로 정확하고 도움이 되는 답변을 제공해야 합니다.

      ## 답변 원칙:
      1. 제공된 규정 내용만을 근거로 답변하세요
      2. 규정에 명시되지 않은 내용은 추측하지 마세요
      3. 답변이 불확실한 경우 "제공된 규정에서는 명확하지 않습니다"라고 명시하세요
      4. 관련 조문 번호와 규정명을 함께 제시하세요
      5. 학생이 이해하기 쉬운 언어로 설명하세요
    PROMPT

    # 안전 모드 추가 지침
    if safety_mode
      base_prompt += <<~SAFETY
        
        ## 안전 지침:
        - 개인정보나 민감한 정보는 절대 요구하거나 제공하지 마세요
        - 규정 해석에 대한 최종 결정은 해당 부서에 문의하도록 안내하세요
        - 법적 조언이나 확정적인 판단은 피하고, 일반적인 정보 제공에 집중하세요
      SAFETY
    end

    # 응답 형식 지침
    base_prompt += build_response_format_instruction

    base_prompt.strip
  end

  # 사용자 프롬프트 구성
  def build_user_prompt
    context_section = build_context_section
    question_section = build_question_section
    
    <<~PROMPT
      #{context_section}

      #{question_section}
    PROMPT
  end

  # 컨텍스트 섹션 구성
  def build_context_section
    return "" if search_results.blank?

    processed_results = process_search_results
    context_text = build_context_text(processed_results)
    
    <<~CONTEXT
      ## 관련 규정 내용:

      #{context_text}
    CONTEXT
  end

  # 질문 섹션 구성
  def build_question_section
    <<~QUESTION
      ## 질문:
      #{question}

      위의 규정 내용을 바탕으로 질문에 대해 정확하고 도움이 되는 답변을 제공해 주세요.
    QUESTION
  end

  # 검색 결과 처리
  def process_search_results
    results = search_results.is_a?(String) ? JSON.parse(search_results) : search_results
    
    # 유사도 순으로 정렬
    sorted_results = results.sort_by { |r| -(r['similarity'] || r[:similarity] || 0) }
    
    # 토큰 제한 내에서 최대한 많은 결과 포함
    selected_results = []
    current_tokens = 0
    
    sorted_results.each do |result|
      result_tokens = estimate_tokens(format_single_result(result))
      
      if current_tokens + result_tokens <= max_context_tokens
        selected_results << result
        current_tokens += result_tokens
      else
        break
      end
    end
    
    selected_results
  end

  # 컨텍스트 텍스트 구성
  def build_context_text(processed_results)
    context_parts = processed_results.map.with_index do |result, index|
      format_single_result(result, index + 1)
    end
    
    context_parts.join("\n\n")
  end

  # 단일 결과 포맷팅
  def format_single_result(result, index = nil)
    title = result['title'] || result[:title]
    content = result['content'] || result[:content]
    number = result['number'] || result[:number]
    regulation_title = result['regulation_title'] || result[:regulation_title]
    regulation_code = result['regulation_code'] || result[:regulation_code]
    similarity = result['similarity'] || result[:similarity]
    
    # 내용 요약 (너무 긴 경우)
    summarized_content = summarize_content(content)
    
    formatted = ""
    formatted += "### #{index}. " if index
    formatted += "#{regulation_title} (#{regulation_code})\n"
    formatted += "**제#{number}조 #{title}**\n\n"
    formatted += "#{summarized_content}"
    formatted += "\n\n*유사도: #{(similarity * 100).round(1)}%*" if similarity && include_sources
    
    formatted
  end

  # 내용 요약
  def summarize_content(content)
    return content if content.length <= 500
    
    # 문장 단위로 분할하여 중요한 부분만 유지
    sentences = content.split(/[.!?。！？]/).map(&:strip).reject(&:blank?)
    
    if sentences.length <= 3
      content
    else
      # 처음 2문장과 마지막 1문장 유지
      key_sentences = sentences.first(2) + sentences.last(1)
      truncated = key_sentences.join('. ') + '.'
      
      if truncated.length > 500
        content.truncate(500, separator: ' ')
      else
        truncated
      end
    end
  end

  # 토큰 수 추정
  def estimate_tokens(text)
    # 간단한 토큰 수 추정 (한글: 1글자 ≈ 1토큰, 영어: 4글자 ≈ 1토큰)
    korean_chars = text.scan(/[가-힣]/).length
    english_chars = text.scan(/[a-zA-Z]/).length
    other_chars = text.length - korean_chars - english_chars
    
    (korean_chars + (english_chars / 4.0) + (other_chars / 2.0)).ceil
  end

  # 응답 형식 지침 구성
  def build_response_format_instruction
    case response_format
    when 'brief'
      "\n\n## 응답 형식:\n간결하고 핵심적인 답변을 1-2문장으로 제공하세요."
    when 'detailed'
      "\n\n## 응답 형식:\n상세하고 구체적인 설명을 제공하되, 관련 조문과 근거를 명시하세요."
    when 'structured'
      <<~STRUCTURED
        
        ## 응답 형식:
        다음 구조로 답변해 주세요:
        
        **답변 요약:**
        [핵심 답변을 1-2문장으로]
        
        **상세 설명:**
        [구체적인 설명과 절차]
        
        **관련 규정:**
        [해당 조문 번호와 규정명]
        
        **추가 안내:**
        [필요한 경우 추가 정보나 문의처]
      STRUCTURED
    else
      ""
    end
  end

  # 컨텍스트 구성
  def build_context
    return {} if search_results.blank?

    processed_results = process_search_results
    
    {
      total_results: search_results.length,
      used_results: processed_results.length,
      estimated_tokens: processed_results.sum { |r| estimate_tokens(format_single_result(r)) },
      max_similarity: processed_results.map { |r| r['similarity'] || r[:similarity] || 0 }.max,
      min_similarity: processed_results.map { |r| r['similarity'] || r[:similarity] || 0 }.min,
      regulations_covered: processed_results.map { |r| r['regulation_code'] || r[:regulation_code] }.uniq
    }
  end

  # 메타데이터 구성
  def build_metadata
    {
      question_length: question.length,
      question_tokens: estimate_tokens(question),
      context_tokens: build_context[:estimated_tokens] || 0,
      total_prompt_tokens: estimate_tokens(build_system_prompt) + 
                          estimate_tokens(build_user_prompt),
      safety_mode: safety_mode,
      response_format: response_format,
      generated_at: Time.current,
      version: '1.0'
    }
  end

  # PII 마스킹 (개인정보 보호)
  def mask_pii(text)
    return text unless safety_mode
    
    # 이메일 마스킹
    text = text.gsub(/[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/, '[이메일]')
    
    # 전화번호 마스킹
    text = text.gsub(/\d{2,3}-\d{3,4}-\d{4}/, '[전화번호]')
    
    # 주민등록번호 마스킹
    text = text.gsub(/\d{6}-\d{7}/, '[주민등록번호]')
    
    text
  end

  # 프롬프트 품질 평가
  def evaluate_prompt_quality
    context_info = build_context
    
    {
      context_coverage: calculate_context_coverage(context_info),
      token_efficiency: calculate_token_efficiency(context_info),
      relevance_score: calculate_relevance_score(context_info),
      completeness_score: calculate_completeness_score(context_info)
    }
  end

  private

  def calculate_context_coverage(context_info)
    return 0 if context_info[:total_results] == 0
    
    (context_info[:used_results].to_f / context_info[:total_results] * 100).round(2)
  end

  def calculate_token_efficiency(context_info)
    return 0 if max_context_tokens == 0
    
    used_tokens = context_info[:estimated_tokens] || 0
    (used_tokens.to_f / max_context_tokens * 100).round(2)
  end

  def calculate_relevance_score(context_info)
    return 0 if context_info[:max_similarity].nil?
    
    (context_info[:max_similarity] * 100).round(2)
  end

  def calculate_completeness_score(context_info)
    # 다양한 규정을 포함하고 있는지 평가
    regulation_diversity = context_info[:regulations_covered]&.length || 0
    coverage = calculate_context_coverage(context_info)
    relevance = calculate_relevance_score(context_info)
    
    # 가중 평균으로 완성도 점수 계산
    ((regulation_diversity * 10) + (coverage * 0.5) + (relevance * 0.4)).round(2)
  end
end