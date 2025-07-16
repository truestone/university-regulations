# frozen_string_literal: true

module Api
  # 채팅 메시지 API 컨트롤러
  class MessagesController < ApplicationController
    skip_before_action :verify_authenticity_token
    before_action :ensure_session_id
    before_action :set_conversation
    before_action :check_conversation_active
    
    # GET /api/conversations/:conversation_id/messages
    def index
      @messages = @conversation.messages.chronological.includes(:conversation)
      
      # 페이지네이션 지원
      page = params[:page]&.to_i || 1
      per_page = [params[:per_page]&.to_i || 50, 100].min # 최대 100개
      
      @messages = @messages.limit(per_page).offset((page - 1) * per_page)
      
      render json: {
        success: true,
        data: {
          messages: @messages.map { |message| message_json(message) },
          pagination: {
            page: page,
            per_page: per_page,
            total_count: @conversation.messages.count,
            total_pages: (@conversation.messages.count.to_f / per_page).ceil
          },
          conversation: {
            id: @conversation.id,
            title: @conversation.title,
            active: @conversation.active?,
            expires_at: @conversation.expires_at.iso8601
          }
        },
        timestamp: Time.current.iso8601
      }, status: :ok
    end
    
    # POST /api/conversations/:conversation_id/messages
    def create
      @message = @conversation.messages.build(message_params)
      @message.role = 'user'
      @message.tokens_used = estimate_tokens(@message.content)
      
      if @message.save
        # AI 응답 생성 (비동기)
        response_job_id = generate_ai_response_async(@message)
        
        render json: {
          success: true,
          data: {
            message: message_json(@message),
            ai_response_job_id: response_job_id,
            conversation: {
              id: @conversation.id,
              messages_count: @conversation.messages.count,
              last_message_at: @conversation.last_message_at.iso8601
            }
          },
          timestamp: Time.current.iso8601
        }, status: :created
      else
        render json: {
          success: false,
          errors: @message.errors.full_messages,
          timestamp: Time.current.iso8601
        }, status: :unprocessable_entity
      end
    end
    
    private
    
    def ensure_session_id
      # API에서는 헤더나 파라미터로 세션 ID 전달
      @session_id = request.headers['X-Chat-Session-ID'] || 
                    params[:session_id] || 
                    session[:chat_session_id]
      
      unless @session_id
        render json: { 
          success: false,
          error: '세션 ID가 필요합니다. X-Chat-Session-ID 헤더를 설정하세요.' 
        }, status: :unauthorized
        return false
      end
      
      session[:chat_session_id] = @session_id
    end
    
    def set_conversation
      @conversation = Conversation.find_by(id: params[:conversation_id])
      
      unless @conversation
        render json: { 
          success: false,
          error: '대화를 찾을 수 없습니다.' 
        }, status: :not_found
        return false
      end
      
      # 세션 소유권 확인
      unless @conversation.session_id == @session_id
        render json: { 
          success: false,
          error: '접근 권한이 없습니다.' 
        }, status: :forbidden
        return false
      end
    end
    
    def check_conversation_active
      if @conversation.expired?
        render json: { 
          success: false,
          error: '대화 세션이 만료되었습니다.',
          expired: true,
          expires_at: @conversation.expires_at.iso8601
        }, status: :gone
        return false
      end
    end
    
    def message_params
      params.require(:message).permit(:content)
    end
    
    def estimate_tokens(content)
      # 간단한 토큰 추정 (실제로는 tiktoken 등을 사용)
      # 한글: 1글자 ≈ 1토큰, 영어: 4글자 ≈ 1토큰
      korean_chars = content.scan(/[가-힣]/).length
      english_chars = content.scan(/[a-zA-Z]/).length
      other_chars = content.length - korean_chars - english_chars
      
      (korean_chars + (english_chars / 4.0) + (other_chars / 2.0)).ceil
    end
    
    def generate_ai_response_async(user_message)
      # RAG 검색 및 AI 응답 생성을 비동기로 처리
      job_id = SecureRandom.uuid
      ChatResponseJob.perform_async(user_message.id, job_id)
      job_id
    end
    
    def message_json(message)
      {
        id: message.id,
        conversation_id: message.conversation_id,
        role: message.role,
        content: message.content,
        tokens_used: message.tokens_used,
        created_at: message.created_at.iso8601,
        updated_at: message.updated_at.iso8601
      }
    end
  end
end