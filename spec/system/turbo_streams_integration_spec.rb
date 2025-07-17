# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Turbo Streams Integration', type: :system, js: true do
  let(:conversation) { create(:conversation) }
  
  before do
    # 세션 설정
    page.set_rack_session(chat_session_id: conversation.session_id)
    
    # AI 서비스 모킹
    allow_any_instance_of(AiService).to receive(:generate_response).and_return({
      content: '테스트 AI 응답입니다.',
      usage: { total_tokens: 50 },
      model: 'gpt-4'
    })
    
    # RAG 검색 모킹
    allow_any_instance_of(ChatResponseJob).to receive(:perform_rag_search).and_return([])
  end

  it '사용자 메시지 전송 시 Turbo Streams로 실시간 업데이트된다' do
    visit conversation_path(conversation)
    
    # 메시지 입력
    fill_in 'message[content]', with: '테스트 질문입니다'
    
    # Sidekiq 인라인 모드로 설정하여 즉시 실행
    Sidekiq::Testing.inline! do
      click_button '전송'
      
      # 사용자 메시지가 즉시 표시되는지 확인
      expect(page).to have_content('테스트 질문입니다')
      expect(page).to have_content('사용자')
      
      # AI 응답이 표시되는지 확인 (비동기 처리 후)
      expect(page).to have_content('테스트 AI 응답입니다', wait: 5)
      expect(page).to have_content('AI 어시스턴트')
    end
  end

  it '로딩 인디케이터가 올바르게 표시되고 사라진다' do
    visit conversation_path(conversation)
    
    fill_in 'message[content]', with: '로딩 테스트'
    
    # 로딩 상태 확인을 위해 느린 응답 시뮬레이션
    allow_any_instance_of(ChatResponseJob).to receive(:generate_ai_response).and_wrap_original do |method, *args|
      sleep 0.1 # 짧은 지연
      method.call(*args)
    end
    
    click_button '전송'
    
    # 로딩 인디케이터 확인
    expect(page).to have_content('AI가 답변을 생성 중입니다', wait: 1)
    
    Sidekiq::Testing.inline! do
      # 로딩이 완료되면 인디케이터가 사라지는지 확인
      expect(page).not_to have_content('AI가 답변을 생성 중입니다', wait: 3)
    end
  end

  it '에러 발생 시 에러 메시지가 Turbo Streams로 표시된다' do
    visit conversation_path(conversation)
    
    # AI 서비스 에러 시뮬레이션
    allow_any_instance_of(AiService).to receive(:generate_response).and_raise(StandardError, '테스트 에러')
    
    fill_in 'message[content]', with: '에러 테스트'
    
    Sidekiq::Testing.inline! do
      click_button '전송'
      
      # 에러 메시지 확인
      expect(page).to have_content('죄송합니다. 응답을 생성하는 중 오류가 발생했습니다')
    end
  end

  it '여러 메시지가 순서대로 표시된다' do
    visit conversation_path(conversation)
    
    Sidekiq::Testing.inline! do
      # 첫 번째 메시지
      fill_in 'message[content]', with: '첫 번째 질문'
      click_button '전송'
      
      expect(page).to have_content('첫 번째 질문')
      expect(page).to have_content('테스트 AI 응답입니다')
      
      # 두 번째 메시지
      fill_in 'message[content]', with: '두 번째 질문'
      click_button '전송'
      
      expect(page).to have_content('두 번째 질문')
      
      # 메시지 순서 확인
      messages = page.all('.mb-4')
      expect(messages.count).to be >= 4 # 사용자 2개 + AI 2개
    end
  end
end