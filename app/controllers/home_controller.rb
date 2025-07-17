class HomeController < ApplicationController
  def index
    # 홈페이지 - 익명 사용자도 채팅 이용 가능
    if user_signed_in? && (current_user.admin? || current_user.super_admin?)
      # 관리자는 대시보드로
      redirect_to admin_dashboard_path
    else
      # 일반 사용자 및 익명 사용자는 채팅 페이지로
      # 익명 세션 ID 생성 또는 기존 세션 사용
      session[:chat_session_id] ||= SecureRandom.uuid
      
      # 기존 활성 대화 찾기 또는 새로 생성
      conversation = Conversation.active.find_by(session_id: session[:chat_session_id])
      
      unless conversation
        conversation = Conversation.create!(
          session_id: session[:chat_session_id],
          title: "새 대화",
          expires_at: 7.days.from_now,
          last_message_at: Time.current
        )
      end
      
      redirect_to conversation_path(conversation)
    end
  end
end
