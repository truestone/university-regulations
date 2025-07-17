# frozen_string_literal: true

# 채팅 AI 응답 생성 백그라운드 작업
class ChatResponseJob
  include Sidekiq::Job
  
  sidekiq_options queue: 'chat', retry: 3, backtrace: true
  
  def perform(user_message_id, job_id = nil)
    user_message = Message.find(user_message_id)
    conversation = user_message.conversation
    
    Rails.logger.info "Generating AI response for message #{user_message_id} (job: #{job_id})"
    
    # 로딩 상태 브로드캐스트
    broadcast_loading_state(conversation, true)
    
    begin
      # 1. RAG 검색으로 관련 문서 찾기
      search_results = perform_rag_search(user_message.content)
      
      # 2. AI 응답 생성
      ai_response = generate_ai_response(user_message, search_results)
      
      # 3. AI 응답 메시지 저장
      ai_message = conversation.messages.create!(
        role: 'assistant',
        content: ai_response[:content],
        tokens_used: ai_response[:tokens_used],
        metadata: {
          job_id: job_id,
          search_results_count: search_results.size,
          model_used: ai_response[:model],
          response_time_ms: ai_response[:response_time],
          sources: search_results.map { |r| { id: r[:id], title: r[:article_title] } }
        }
      )
      
      # 4. 실시간 브로드캐스트 (Turbo Streams)
      broadcast_loading_state(conversation, false)
      broadcast_ai_response(ai_message)
      
      Rails.logger.info "AI response generated successfully for message #{user_message_id}"
      
    rescue => e
      Rails.logger.error "Failed to generate AI response for message #{user_message_id}: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      
      # 에러 메시지 생성
      error_message = conversation.messages.create!(
        role: 'assistant',
        content: "죄송합니다. 응답을 생성하는 중 오류가 발생했습니다. 다시 시도해 주세요.",
        tokens_used: 20,
        metadata: {
          job_id: job_id,
          error: e.message,
          error_type: e.class.name
        }
      )
      
      broadcast_loading_state(conversation, false)
      broadcast_ai_response(error_message)
      
      # 에러를 다시 발생시켜 Sidekiq 재시도 메커니즘 활용
      raise e
    end
  end
  
  private
  
  def perform_rag_search(query)
    # RAG 오케스트레이터를 사용한 검색
    rag_result = RagOrchestratorService.execute(query, {
      max_sources: 5,
      search_type: 'hybrid'
    })
    
    return [] unless rag_result && rag_result[:sources]
    
    # 검색 결과를 표준 형식으로 변환
    rag_result[:sources].map do |source|
      if source.is_a?(Hash)
        source
      else
        # Article 객체인 경우
        {
          id: source.id,
          regulation_title: source.regulation.title,
          regulation_code: source.regulation.regulation_code,
          article_number: source.number,
          article_title: source.title,
          content: source.content,
          similarity_score: source.try(:similarity_score) || 0.0
        }
      end
    end
  end
  
  def generate_ai_response(user_message, search_results)
    start_time = Time.current
    
    # 컨텍스트 구성
    context = build_context(search_results)
    
    # AI 서비스를 통한 응답 생성
    ai_service = AiService.new
    
    prompt = build_prompt(user_message.content, context)
    
    response = ai_service.generate_response(
      prompt: prompt,
      model: 'gpt-4',
      temperature: 0.1,
      max_tokens: 1000
    )
    
    {
      content: response[:content],
      tokens_used: response[:usage][:total_tokens],
      model: response[:model],
      response_time: ((Time.current - start_time) * 1000).round(2)
    }
  end
  
  def build_context(search_results)
    return "관련 규정을 찾을 수 없습니다." if search_results.empty?
    
    context_parts = search_results.map.with_index do |result, index|
      <<~CONTEXT
        [참고자료 #{index + 1}]
        규정: #{result[:regulation_title]} (#{result[:regulation_code]})
        조문: 제#{result[:article_number]}조 #{result[:article_title]}
        내용: #{result[:content]}
        관련도: #{(result[:similarity_score] * 100).round(1)}%
      CONTEXT
    end
    
    context_parts.join("\n\n")
  end
  
  def build_prompt(user_question, context)
    <<~PROMPT
      당신은 대학 규정 전문가입니다. 사용자의 질문에 대해 제공된 규정 자료를 바탕으로 정확하고 도움이 되는 답변을 제공해주세요.

      사용자 질문: #{user_question}

      관련 규정 자료:
      #{context}

      답변 지침:
      1. 제공된 규정 자료를 바탕으로 답변하세요
      2. 구체적인 조문과 규정명을 인용하세요
      3. 명확하고 이해하기 쉽게 설명하세요
      4. 관련 자료가 없다면 솔직히 말씀드리세요
      5. 추가 문의가 필요한 경우 안내해주세요

      답변:
    PROMPT
  end
  
  def broadcast_ai_response(ai_message)
    # Turbo Streams를 통한 실시간 브로드캐스트
    conversation = ai_message.conversation
    
    Turbo::StreamsChannel.broadcast_append_to(
      "conversation_#{conversation.id}",
      target: "messages",
      partial: "messages/message",
      locals: { message: ai_message }
    )
    
    # 메시지 폼 리셋
    Turbo::StreamsChannel.broadcast_replace_to(
      "conversation_#{conversation.id}",
      target: "message-form",
      partial: "messages/form",
      locals: { conversation: conversation, message: Message.new }
    )
  end
  
  def broadcast_loading_state(conversation, is_loading)
    # 로딩 인디케이터 표시/숨김
    if is_loading
      Turbo::StreamsChannel.broadcast_update_to(
        "conversation_#{conversation.id}",
        target: "loadingIndicator",
        partial: "messages/loading_indicator"
      )
    else
      Turbo::StreamsChannel.broadcast_update_to(
        "conversation_#{conversation.id}",
        target: "loadingIndicator", 
        html: ""
      )
    end
  end
end