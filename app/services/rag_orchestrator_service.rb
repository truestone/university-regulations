# frozen_string_literal: true

# RAG 시스템 전체 오케스트레이션 서비스
class RagOrchestratorService
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :question, :string
  attribute :options, :string, default: -> { {} }

  validates :question, presence: true, length: { minimum: 3, maximum: 500 }

  # 전체 RAG 파이프라인 실행
  def self.execute(question, options = {})
    service = new(question: question, options: options)
    service.execute
  end

  def execute
    return nil unless valid?

    Rails.logger.info "RAG Orchestrator executing for: #{question.truncate(100)}"
    
    start_time = Time.current
    pipeline_steps = []

    begin
      # Step 1: 질문 전처리 및 임베딩 생성
      step_result = execute_step("question_embedding") do
        QuestionEmbeddingService.generate_embedding(question, options)
      end
      pipeline_steps << step_result
      
      return build_error_response("질문 처리 실패", pipeline_steps) unless step_result[:success]

      # Step 2: 벡터 검색 실행
      step_result = execute_step("vector_search") do
        search_options = build_search_options
        search_service = VectorSearchService.new(question, search_options)
        search_service.search
      end
      pipeline_steps << step_result
      
      return build_error_response("검색 실패", pipeline_steps) unless step_result[:success]
      
      search_results = step_result[:data]
      return build_error_response("검색 결과 없음", pipeline_steps) if search_results.empty?

      # Step 3: 프롬프트 생성
      step_result = execute_step("prompt_generation") do
        RagPromptService.generate_prompt(
          question: question,
          search_results: search_results,
          **build_prompt_options
        )
      end
      pipeline_steps << step_result
      
      return build_error_response("프롬프트 생성 실패", pipeline_steps) unless step_result[:success]

      # Step 4: GPT 답변 생성
      step_result = execute_step("gpt_answer") do
        GptAnswerService.generate_answer(
          question: question,
          search_results: search_results,
          **build_gpt_options
        )
      end
      pipeline_steps << step_result
      
      return build_error_response("답변 생성 실패", pipeline_steps) unless step_result[:success]

      # Step 5: 후처리 및 검증
      step_result = execute_step("post_processing") do
        post_process_answer(step_result[:data], search_results)
      end
      pipeline_steps << step_result

      # 최종 결과 구성
      build_success_response(step_result[:data], pipeline_steps, start_time)

    rescue => e
      Rails.logger.error "RAG Orchestrator error: #{e.message}"
      build_error_response(e.message, pipeline_steps, e)
    end
  end

  private

  # 파이프라인 단계 실행
  def execute_step(step_name, &block)
    step_start = Time.current
    
    begin
      Rails.logger.debug "Executing RAG step: #{step_name}"
      
      result = yield
      execution_time = ((Time.current - step_start) * 1000).round(2)
      
      {
        step: step_name,
        success: true,
        data: result,
        execution_time_ms: execution_time,
        timestamp: Time.current
      }
      
    rescue => e
      execution_time = ((Time.current - step_start) * 1000).round(2)
      
      Rails.logger.error "RAG step #{step_name} failed: #{e.message}"
      
      {
        step: step_name,
        success: false,
        error: e.message,
        error_type: e.class.name,
        execution_time_ms: execution_time,
        timestamp: Time.current
      }
    end
  end

  # 검색 옵션 구성
  def build_search_options
    {
      limit: options[:search_limit] || 10,
      similarity_threshold: options[:similarity_threshold] || 0.7,
      include_context: options[:include_context] != false,
      filter_active_only: options[:filter_active_only] != false
    }
  end

  # 프롬프트 옵션 구성
  def build_prompt_options
    {
      max_context_tokens: options[:max_context_tokens] || 3000,
      include_sources: options[:include_sources] != false,
      safety_mode: options[:safety_mode] != false,
      response_format: options[:response_format] || 'detailed'
    }
  end

  # GPT 옵션 구성
  def build_gpt_options
    {
      model: options[:model] || 'gpt-4',
      temperature: options[:temperature] || 0.3,
      max_tokens: options[:max_tokens] || 1000,
      response_format: options[:response_format] || 'detailed'
    }
  end

  # 답변 후처리
  def post_process_answer(answer_data, search_results)
    # 답변 품질 검증
    quality_score = calculate_answer_quality(answer_data, search_results)
    
    # 소스 정보 보강
    enhanced_sources = enhance_source_information(answer_data[:sources])
    
    # 관련 추천 질문 생성
    related_questions = generate_related_questions(question, search_results)
    
    {
      answer: answer_data[:answer],
      sources: enhanced_sources,
      metadata: answer_data[:metadata].merge(
        quality_score: quality_score,
        post_processed: true
      ),
      related_questions: related_questions,
      confidence_level: calculate_confidence_level(quality_score, search_results)
    }
  end

  # 답변 품질 계산
  def calculate_answer_quality(answer_data, search_results)
    base_score = answer_data[:metadata][:quality_score] || 0
    
    # 검색 결과 품질 보정
    search_quality = search_results.map { |r| r[:similarity] || 0 }.max || 0
    search_bonus = (search_quality * 20).round
    
    # 소스 다양성 보정
    unique_regulations = search_results.map { |r| r[:regulation_id] }.uniq.length
    diversity_bonus = [unique_regulations * 5, 15].min
    
    total_score = base_score + search_bonus + diversity_bonus
    [total_score, 100].min
  end

  # 소스 정보 보강
  def enhance_source_information(sources)
    sources.map do |source|
      source.merge(
        url: build_regulation_url(source),
        context_snippet: build_context_snippet(source),
        relevance_explanation: build_relevance_explanation(source)
      )
    end
  end

  # 규정 URL 구성
  def build_regulation_url(source)
    # 실제 구현에서는 규정 조회 페이지 URL 생성
    "/regulations/#{source[:regulation_id]}/articles/#{source[:id]}"
  end

  # 컨텍스트 스니펫 생성
  def build_context_snippet(source)
    content = source[:content] || ""
    # 질문과 관련된 부분을 하이라이트
    content.truncate(200, separator: ' ')
  end

  # 관련성 설명 생성
  def build_relevance_explanation(source)
    similarity = source[:similarity] || 0
    
    case similarity
    when 0.9..1.0
      "매우 관련성이 높은 규정입니다"
    when 0.8..0.9
      "관련성이 높은 규정입니다"
    when 0.7..0.8
      "어느 정도 관련된 규정입니다"
    else
      "참고할 만한 규정입니다"
    end
  end

  # 관련 질문 생성
  def generate_related_questions(original_question, search_results)
    # 검색 결과를 바탕으로 관련 질문 생성
    regulations = search_results.map { |r| r[:regulation_title] }.uniq.first(3)
    
    related = []
    
    regulations.each do |regulation_title|
      related << "#{regulation_title}에 대해 더 자세히 알려주세요"
      related << "#{regulation_title}의 예외 사항은 무엇인가요?"
    end
    
    # 일반적인 관련 질문 추가
    if original_question.include?('기한')
      related << "연체 시 어떤 조치가 취해지나요?"
      related << "기한 연장이 가능한가요?"
    end
    
    if original_question.include?('신청')
      related << "신청 절차는 어떻게 되나요?"
      related << "필요한 서류는 무엇인가요?"
    end
    
    related.uniq.first(5)
  end

  # 신뢰도 수준 계산
  def calculate_confidence_level(quality_score, search_results)
    max_similarity = search_results.map { |r| r[:similarity] || 0 }.max || 0
    result_count = search_results.length
    
    # 품질 점수, 최대 유사도, 결과 수를 종합하여 신뢰도 계산
    confidence = (quality_score * 0.4) + (max_similarity * 100 * 0.4) + ([result_count, 10].min * 2)
    
    case confidence
    when 80..100
      'high'
    when 60..79
      'medium'
    when 40..59
      'low'
    else
      'very_low'
    end
  end

  # 성공 응답 구성
  def build_success_response(final_data, pipeline_steps, start_time)
    total_execution_time = ((Time.current - start_time) * 1000).round(2)
    
    {
      success: true,
      question: question,
      answer: final_data[:answer],
      sources: final_data[:sources],
      related_questions: final_data[:related_questions],
      confidence_level: final_data[:confidence_level],
      metadata: final_data[:metadata].merge(
        total_execution_time_ms: total_execution_time,
        pipeline_steps: pipeline_steps.map { |step| step.except(:data) },
        orchestrator_version: '1.0'
      ),
      timestamp: Time.current
    }
  end

  # 에러 응답 구성
  def build_error_response(error_message, pipeline_steps, exception = nil)
    {
      success: false,
      question: question,
      error: error_message,
      error_type: exception&.class&.name,
      pipeline_steps: pipeline_steps.map { |step| step.except(:data) },
      timestamp: Time.current
    }
  end

  # 파이프라인 성능 분석
  def analyze_pipeline_performance(pipeline_steps)
    total_time = pipeline_steps.sum { |step| step[:execution_time_ms] || 0 }
    
    analysis = {
      total_execution_time_ms: total_time,
      step_breakdown: {},
      bottlenecks: [],
      recommendations: []
    }
    
    pipeline_steps.each do |step|
      step_time = step[:execution_time_ms] || 0
      analysis[:step_breakdown][step[:step]] = {
        time_ms: step_time,
        percentage: total_time > 0 ? (step_time / total_time * 100).round(2) : 0
      }
      
      # 병목 지점 식별
      if step_time > 1000  # 1초 이상
        analysis[:bottlenecks] << step[:step]
      end
    end
    
    # 최적화 권장사항
    if analysis[:bottlenecks].include?('vector_search')
      analysis[:recommendations] << "벡터 검색 성능 최적화 필요"
    end
    
    if analysis[:bottlenecks].include?('gpt_answer')
      analysis[:recommendations] << "GPT 모델 또는 토큰 수 조정 고려"
    end
    
    analysis
  end
end