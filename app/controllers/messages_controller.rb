# frozen_string_literal: true

# 채팅 메시지 관리 컨트롤러
class MessagesController < ApplicationController
  before_action :ensure_session_id
  before_action :set_conversation
  before_action :check_conversation_active
  # 인증 불필요 - 익명 사용자도 메시지 전송 가능
  
  # POST /chat/:conversation_id/messages
  def create
    @message = @conversation.messages.build(message_params)
    @message.role = 'user'
    @message.tokens_used = estimate_tokens(@message.content)
    
    respond_to do |format|
      if @message.save
        # AI 응답 생성 (비동기)
        generate_ai_response_async(@message)
        
        format.html { redirect_to conversation_path(@conversation) }
        format.json { render json: message_json(@message), status: :created }
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.append("messages", partial: "messages/message", locals: { message: @message }),
            turbo_stream.replace("message-form", partial: "messages/form", locals: { conversation: @conversation, message: Message.new })
          ]
        end
      else
        format.html { redirect_to conversation_path(@conversation), alert: '메시지를 전송할 수 없습니다.' }
        format.json { render json: { errors: @message.errors }, status: :unprocessable_entity }
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace("message-form", partial: "messages/form", locals: { conversation: @conversation, message: @message })
        end
      end
    end
  end
  
  private
  
  def ensure_session_id
    session[:chat_session_id] ||= SecureRandom.uuid
  end
  
  def set_conversation
    @conversation = Conversation.find_by(id: params[:conversation_id])
    
    unless @conversation
      respond_to do |format|
        format.html { redirect_to root_path, alert: '대화를 찾을 수 없습니다.' }
        format.json { render json: { error: '대화를 찾을 수 없습니다.' }, status: :not_found }
        format.turbo_stream { render turbo_stream: turbo_stream.replace("flash", partial: "shared/flash", locals: { alert: '대화를 찾을 수 없습니다.' }) }
      end
      return false
    end
    
    # 세션 소유권 확인
    unless @conversation.session_id == session[:chat_session_id]
      respond_to do |format|
        format.html { redirect_to root_path, alert: '접근 권한이 없습니다.' }
        format.json { render json: { error: '접근 권한이 없습니다.' }, status: :forbidden }
        format.turbo_stream { render turbo_stream: turbo_stream.replace("flash", partial: "shared/flash", locals: { alert: '접근 권한이 없습니다.' }) }
      end
      return false
    end
  end
  
  def check_conversation_active
    if @conversation.expired?
      respond_to do |format|
        format.html { redirect_to root_path, alert: '대화 세션이 만료되었습니다.' }
        format.json { render json: { error: '대화 세션이 만료되었습니다.' }, status: :gone }
        format.turbo_stream { render turbo_stream: turbo_stream.replace("flash", partial: "shared/flash", locals: { alert: '대화 세션이 만료되었습니다.' }) }
      end
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
    ChatResponseJob.perform_async(user_message.id)
  end
  
  def message_json(message)
    {
      id: message.id,
      conversation_id: message.conversation_id,
      role: message.role,
      content: message.content,
      tokens_used: message.tokens_used,
      created_at: message.created_at,
      conversation: {
        id: message.conversation.id,
        title: message.conversation.title,
        expires_at: message.conversation.expires_at,
        active: message.conversation.active?
      }
    }
  end
end