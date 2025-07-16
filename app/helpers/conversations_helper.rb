# frozen_string_literal: true

# 채팅 대화 관련 헬퍼 메서드
module ConversationsHelper
  # 대화 상태 배지 생성
  def conversation_status_badge(conversation)
    if conversation.active?
      content_tag :span, "활성", 
        class: "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800"
    else
      content_tag :span, "만료됨", 
        class: "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-red-100 text-red-800"
    end
  end

  # 대화 만료까지 남은 시간 표시
  def conversation_expires_in(conversation)
    return "만료됨" unless conversation.active?
    
    time_left = conversation.expires_at - Time.current
    
    if time_left > 1.day
      "#{(time_left / 1.day).floor}일 #{((time_left % 1.day) / 1.hour).floor}시간"
    elsif time_left > 1.hour
      "#{(time_left / 1.hour).floor}시간 #{((time_left % 1.hour) / 1.minute).floor}분"
    elsif time_left > 1.minute
      "#{(time_left / 1.minute).floor}분"
    else
      "곧 만료"
    end
  end

  # 메시지 수 표시
  def conversation_messages_count(conversation)
    count = conversation.messages.count
    "메시지 #{count}개"
  end

  # 대화 요약 생성
  def conversation_summary(conversation)
    return "새 대화" if conversation.messages.empty?
    
    first_user_message = conversation.messages.user_messages.first
    return "새 대화" unless first_user_message
    
    truncate(first_user_message.content, length: 50)
  end

  # 새 대화 시작 링크
  def new_conversation_link(text = "새 대화 시작", options = {})
    default_options = {
      method: :post,
      class: "inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
    }
    
    link_to text, conversations_path, default_options.merge(options)
  end

  # 채팅 세션 ID 메타 태그
  def chat_session_meta_tag
    session_id = session[:chat_session_id] || SecureRandom.uuid
    session[:chat_session_id] = session_id
    tag.meta name: "chat-session-id", content: session_id
  end
end