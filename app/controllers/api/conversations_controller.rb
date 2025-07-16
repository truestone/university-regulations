# frozen_string_literal: true

module Api
  # 채팅 대화 세션 API 컨트롤러
  class ConversationsController < ApplicationController
    skip_before_action :verify_authenticity_token
    before_action :ensure_session_id
    before_action :set_conversation, only: [:show, :destroy, :extend_session, :status]
    before_action :check_conversation_active, only: [:show, :status]
    
    # GET /api/conversations/:id
    def show
      render json: conversation_json(@conversation), status: :ok
    end
    
    # POST /api/conversations
    def create
      @conversation = find_or_create_conversation
      
      if @conversation.persisted?
        render json: conversation_json(@conversation), status: :created
      else
        render json: { 
          success: false,
          errors: @conversation.errors.full_messages 
        }, status: :unprocessable_entity
      end
    end
    
    # DELETE /api/conversations/:id
    def destroy
      if @conversation.destroy
        reset_session_id
        render json: { 
          success: true,
          message: '대화가 종료되었습니다.' 
        }, status: :ok
      else
        render json: { 
          success: false,
          errors: @conversation.errors.full_messages 
        }, status: :unprocessable_entity
      end
    end
    
    # POST /api/conversations/:id/extend_session
    def extend_session
      if @conversation.update(expires_at: 7.days.from_now)
        render json: conversation_json(@conversation), status: :ok
      else
        render json: { 
          success: false,
          errors: @conversation.errors.full_messages 
        }, status: :unprocessable_entity
      end
    end
    
    # GET /api/conversations/:id/status
    def status
      render json: {
        id: @conversation.id,
        active: @conversation.active?,
        expires_at: @conversation.expires_at,
        expires_in_seconds: (@conversation.expires_at - Time.current).to_i,
        messages_count: @conversation.messages.count,
        last_message_at: @conversation.last_message_at
      }, status: :ok
    end
    
    private
    
    def ensure_session_id
      # API에서는 헤더나 파라미터로 세션 ID 전달
      @session_id = request.headers['X-Chat-Session-ID'] || 
                    params[:session_id] || 
                    session[:chat_session_id] ||
                    SecureRandom.uuid
      
      session[:chat_session_id] = @session_id
    end
    
    def set_conversation
      @conversation = Conversation.find_by(id: params[:id])
      
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
          expires_at: @conversation.expires_at
        }, status: :gone
        return false
      end
    end
    
    def find_or_create_conversation
      # 기존 활성 대화 찾기
      existing_conversation = Conversation.active.find_by(session_id: @session_id)
      return existing_conversation if existing_conversation
      
      # 새 대화 생성
      Conversation.create(
        session_id: @session_id,
        title: params[:title] || "대화 #{Time.current.strftime('%Y-%m-%d %H:%M')}",
        expires_at: 7.days.from_now,
        last_message_at: Time.current
      )
    end
    
    def reset_session_id
      session.delete(:chat_session_id)
    end
    
    def conversation_json(conversation)
      {
        success: true,
        data: {
          id: conversation.id,
          title: conversation.title,
          session_id: conversation.session_id,
          created_at: conversation.created_at.iso8601,
          expires_at: conversation.expires_at.iso8601,
          expires_in_seconds: (conversation.expires_at - Time.current).to_i,
          last_message_at: conversation.last_message_at&.iso8601,
          active: conversation.active?,
          messages_count: conversation.messages.count
        },
        timestamp: Time.current.iso8601
      }
    end
  end
end