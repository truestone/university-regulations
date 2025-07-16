# frozen_string_literal: true

# 채팅 메시지 관련 헬퍼 메서드
module MessagesHelper
  # 메시지 역할에 따른 아바타 아이콘
  def message_avatar(message)
    if message.user_message?
      content_tag :div, "👤", 
        class: "w-8 h-8 rounded-full bg-blue-600 text-white flex items-center justify-center text-sm"
    else
      content_tag :div, "🤖", 
        class: "w-8 h-8 rounded-full bg-gray-600 text-white flex items-center justify-center text-sm"
    end
  end

  # 메시지 시간 포맷팅
  def message_timestamp(message)
    if message.created_at.today?
      message.created_at.strftime("%H:%M")
    elsif message.created_at > 1.week.ago
      message.created_at.strftime("%m/%d %H:%M")
    else
      message.created_at.strftime("%Y/%m/%d %H:%M")
    end
  end

  # 토큰 사용량 표시
  def message_tokens_badge(message)
    color_class = case message.tokens_used
                  when 0..50 then "bg-green-100 text-green-800"
                  when 51..200 then "bg-yellow-100 text-yellow-800"
                  else "bg-red-100 text-red-800"
                  end

    content_tag :span, "#{message.tokens_used} 토큰", 
      class: "inline-flex items-center px-2 py-1 rounded-full text-xs font-medium #{color_class}"
  end

  # 메시지 내용 포맷팅 (마크다운 지원)
  def format_message_content(content)
    # 간단한 마크다운 지원
    formatted = content.dup
    
    # 볼드 텍스트
    formatted.gsub!(/\*\*(.*?)\*\*/, '<strong>\1</strong>')
    
    # 이탤릭 텍스트
    formatted.gsub!(/\*(.*?)\*/, '<em>\1</em>')
    
    # 코드 블록
    formatted.gsub!(/`(.*?)`/, '<code class="bg-gray-100 px-1 py-0.5 rounded text-sm">\1</code>')
    
    # 줄바꿈 처리
    formatted = simple_format(formatted)
    
    # 링크 자동 생성
    formatted = auto_link(formatted, html: { target: '_blank', class: 'text-blue-600 hover:underline' })
    
    formatted.html_safe
  end

  # AI 응답의 소스 정보 표시
  def message_sources(message)
    return unless message.assistant_message? && message.metadata&.dig('sources')&.any?
    
    sources = message.metadata['sources']
    
    content_tag :div, class: "mt-3 pt-3 border-t border-gray-200" do
      content_tag(:div, "참고 자료:", class: "text-xs font-medium text-gray-600 mb-2") +
      content_tag(:ul, class: "text-xs text-gray-500 space-y-1") do
        sources.map do |source|
          content_tag :li, class: "flex items-center space-x-2" do
            content_tag(:span, "📄", class: "text-blue-500") +
            content_tag(:span, source['title'] || "규정 자료")
          end
        end.join.html_safe
      end
    end
  end

  # 메시지 로딩 인디케이터
  def message_loading_indicator
    content_tag :div, class: "mb-4 flex justify-start" do
      content_tag :div, class: "max-w-3xl bg-gray-100 text-gray-900 rounded-lg p-3 shadow-sm" do
        content_tag(:div, "AI가 응답을 생성하고 있습니다...", class: "text-sm text-gray-600") +
        content_tag(:div, class: "flex space-x-1 mt-2") do
          3.times.map do |i|
            content_tag :div, "", 
              class: "w-2 h-2 bg-gray-400 rounded-full animate-pulse",
              style: "animation-delay: #{i * 0.2}s"
          end.join.html_safe
        end
      end
    end
  end

  # 메시지 에러 표시
  def message_error_indicator(error_message = "메시지 전송에 실패했습니다.")
    content_tag :div, class: "mb-4 flex justify-center" do
      content_tag :div, class: "bg-red-50 border border-red-200 rounded-lg p-3 text-red-700 text-sm" do
        content_tag(:span, "⚠️ ", class: "mr-1") + error_message
      end
    end
  end
end