# frozen_string_literal: true

# 채팅 대화 세션 관리 컨트롤러
class ConversationsController < ApplicationController
  before_action :ensure_session_id
  before_action :set_conversation, only: [:show, :destroy, :extend_session]
  before_action :check_conversation_active, only: [:show]
  
  # GET /chat/:id
  def show
    @messages = @conversation.messages.chronological.includes(:conversation)
    
    respond_to do |format|
      format.html
      format.json { render json: conversation_json(@conversation) }
    end
  end
  
  # POST /chat
  def create
    @conversation = find_or_create_conversation
    
    respond_to do |format|
      if @conversation.persisted?
        format.html { redirect_to conversation_path(@conversation) }
        format.json { render json: conversation_json(@conversation), status: :created }
      else
        format.html { redirect_to root_path, alert: '대화 세션을 생성할 수 없습니다.' }
        format.json { render json: { errors: @conversation.errors }, status: :unprocessable_entity }
      end
    end
  end
  
  # DELETE /chat/:id
  def destroy
    if @conversation.destroy
      reset_session_id
      
      respond_to do |format|
        format.html { redirect_to root_path, notice: '대화가 종료되었습니다.' }
        format.json { render json: { message: '대화가 종료되었습니다.' }, status: :ok }
      end
    else
      respond_to do |format|
        format.html { redirect_to conversation_path(@conversation), alert: '대화를 종료할 수 없습니다.' }
        format.json { render json: { errors: @conversation.errors }, status: :unprocessable_entity }
      end
    end
  end
  
  # POST /chat/:id/extend_session
  def extend_session
    if @conversation.update(expires_at: 7.days.from_now)
      respond_to do |format|
        format.html { redirect_to conversation_path(@conversation), notice: '세션이 연장되었습니다.' }
        format.json { render json: conversation_json(@conversation), status: :ok }
      end
    else
      respond_to do |format|
        format.html { redirect_to conversation_path(@conversation), alert: '세션을 연장할 수 없습니다.' }
        format.json { render json: { errors: @conversation.errors }, status: :unprocessable_entity }
      end
    end
  end
  
  private
  
  def ensure_session_id
    session[:chat_session_id] ||= SecureRandom.uuid
  end
  
  def set_conversation
    @conversation = Conversation.find_by(id: params[:id])
    
    unless @conversation
      respond_to do |format|
        format.html { redirect_to root_path, alert: '대화를 찾을 수 없습니다.' }
        format.json { render json: { error: '대화를 찾을 수 없습니다.' }, status: :not_found }
      end
      return false
    end
    
    # 세션 소유권 확인
    unless @conversation.session_id == session[:chat_session_id]
      respond_to do |format|
        format.html { redirect_to root_path, alert: '접근 권한이 없습니다.' }
        format.json { render json: { error: '접근 권한이 없습니다.' }, status: :forbidden }
      end
      return false
    end
  end
  
  def check_conversation_active
    if @conversation.expired?
      respond_to do |format|
        format.html { redirect_to root_path, alert: '대화 세션이 만료되었습니다.' }
        format.json { render json: { error: '대화 세션이 만료되었습니다.' }, status: :gone }
      end
      return false
    end
  end
  
  def find_or_create_conversation
    # 기존 활성 대화 찾기
    existing_conversation = Conversation.active.find_by(session_id: session[:chat_session_id])
    return existing_conversation if existing_conversation
    
    # 새 대화 생성
    Conversation.create(
      session_id: session[:chat_session_id],
      title: "대화 #{Time.current.strftime('%Y-%m-%d %H:%M')}",
      expires_at: 7.days.from_now,
      last_message_at: Time.current
    )
  end
  
  def reset_session_id
    session.delete(:chat_session_id)
  end
  
  def conversation_json(conversation)
    {
      id: conversation.id,
      title: conversation.title,
      session_id: conversation.session_id,
      created_at: conversation.created_at,
      expires_at: conversation.expires_at,
      last_message_at: conversation.last_message_at,
      active: conversation.active?,
      messages_count: conversation.messages.count,
      messages: conversation.messages.chronological.map do |message|
        {
          id: message.id,
          role: message.role,
          content: message.content,
          tokens_used: message.tokens_used,
          created_at: message.created_at
        }
      end
    }
  end
end