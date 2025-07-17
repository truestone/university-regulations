# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ChatResponseJob, type: :job do
  include ActiveJob::TestHelper
  
  let(:conversation) { create(:conversation) }
  let(:user_message) { create(:message, conversation: conversation, role: 'user', content: '학사 규정에 대해 알려주세요') }
  
  before do
    # Turbo Streams 브로드캐스트 모킹
    allow(Turbo::StreamsChannel).to receive(:broadcast_append_to)
    allow(Turbo::StreamsChannel).to receive(:broadcast_replace_to)
    
    # RAG 검색 결과 모킹
    allow_any_instance_of(ChatResponseJob).to receive(:perform_rag_search).and_return([
      {
        id: 1,
        regulation_title: '학사 규정',
        regulation_code: 'ACAD-001',
        article_number: '1',
        article_title: '목적',
        content: '이 규정은 학사 업무에 관한 사항을 정함을 목적으로 한다.',
        similarity_score: 0.95
      }
    ])
    
    # AI 서비스 응답 모킹
    allow_any_instance_of(AiService).to receive(:generate_response).and_return({
      content: '학사 규정은 대학의 학사 업무 전반을 규율하는 규정입니다.',
      usage: { total_tokens: 150 },
      model: 'gpt-4'
    })
  end
  
  describe '#perform' do
    context 'AI 응답 생성 성공 시' do
      it 'AI 메시지를 생성하고 브로드캐스트한다' do
        expect {
          described_class.new.perform(user_message.id, 'test-job-123')
        }.to change { conversation.messages.count }.by(1)
        
        ai_message = conversation.messages.assistant_messages.last
        
        expect(ai_message.content).to eq('학사 규정은 대학의 학사 업무 전반을 규율하는 규정입니다.')
        expect(ai_message.tokens_used).to eq(150)
        expect(ai_message.metadata['job_id']).to eq('test-job-123')
        expect(ai_message.metadata['sources']).to be_present
        
        # 브로드캐스트 호출 확인
        expect(Turbo::StreamsChannel).to have_received(:broadcast_append_to).with(
          "conversation_#{conversation.id}",
          target: "messages",
          partial: "messages/message",
          locals: { message: ai_message }
        )
        
        expect(Turbo::StreamsChannel).to have_received(:broadcast_replace_to).with(
          "conversation_#{conversation.id}",
          target: "message-form",
          partial: "messages/form",
          locals: { conversation: conversation, message: instance_of(Message) }
        )
      end
      
      it '메타데이터에 검색 결과와 성능 정보를 포함한다' do
        described_class.new.perform(user_message.id)
        
        ai_message = conversation.messages.assistant_messages.last
        metadata = ai_message.metadata
        
        expect(metadata['search_results_count']).to eq(1)
        expect(metadata['model_used']).to eq('gpt-4')
        expect(metadata['response_time_ms']).to be_a(Numeric)
        expect(metadata['sources']).to eq([{ 'id' => 1, 'title' => '목적' }])
      end
    end
    
    context 'AI 응답 생성 실패 시' do
      before do
        allow_any_instance_of(AiService).to receive(:generate_response).and_raise(StandardError, 'API 호출 실패')
      end
      
      it '에러 메시지를 생성하고 브로드캐스트한다' do
        expect {
          expect {
            described_class.new.perform(user_message.id, 'error-job-456')
          }.to raise_error(StandardError, 'API 호출 실패')
        }.to change { conversation.messages.count }.by(1)
        
        error_message = conversation.messages.assistant_messages.last
        
        expect(error_message.content).to include('죄송합니다. 응답을 생성하는 중 오류가 발생했습니다.')
        expect(error_message.metadata['job_id']).to eq('error-job-456')
        expect(error_message.metadata['error']).to eq('API 호출 실패')
        expect(error_message.metadata['error_type']).to eq('StandardError')
        
        # 에러 메시지도 브로드캐스트되는지 확인
        expect(Turbo::StreamsChannel).to have_received(:broadcast_append_to).with(
          "conversation_#{conversation.id}",
          target: "messages",
          partial: "messages/message",
          locals: { message: error_message }
        )
      end
    end
    
    context 'RAG 검색 결과가 없는 경우' do
      before do
        allow_any_instance_of(ChatResponseJob).to receive(:perform_rag_search).and_return([])
      end
      
      it '검색 결과 없음을 알리는 컨텍스트로 응답을 생성한다' do
        described_class.new.perform(user_message.id)
        
        ai_message = conversation.messages.assistant_messages.last
        expect(ai_message.metadata['search_results_count']).to eq(0)
        expect(ai_message.metadata['sources']).to eq([])
      end
    end
  end
  
  describe '#broadcast_ai_response' do
    let(:ai_message) { create(:message, conversation: conversation, role: 'assistant') }
    let(:job) { described_class.new }
    
    it '메시지 추가와 폼 리셋을 브로드캐스트한다' do
      job.send(:broadcast_ai_response, ai_message)
      
      expect(Turbo::StreamsChannel).to have_received(:broadcast_append_to).with(
        "conversation_#{conversation.id}",
        target: "messages",
        partial: "messages/message",
        locals: { message: ai_message }
      )
      
      expect(Turbo::StreamsChannel).to have_received(:broadcast_replace_to).with(
        "conversation_#{conversation.id}",
        target: "message-form",
        partial: "messages/form",
        locals: { conversation: conversation, message: instance_of(Message) }
      )
    end
  end
  
  describe '#build_context' do
    let(:job) { described_class.new }
    
    context '검색 결과가 있는 경우' do
      let(:search_results) do
        [
          {
            regulation_title: '학사 규정',
            regulation_code: 'ACAD-001',
            article_number: '1',
            article_title: '목적',
            content: '이 규정은 학사 업무에 관한 사항을 정함을 목적으로 한다.',
            similarity_score: 0.95
          },
          {
            regulation_title: '학사 규정',
            regulation_code: 'ACAD-001',
            article_number: '2',
            article_title: '적용범위',
            content: '이 규정은 모든 학부생에게 적용된다.',
            similarity_score: 0.87
          }
        ]
      end
      
      it '구조화된 컨텍스트 문자열을 생성한다' do
        context = job.send(:build_context, search_results)
        
        expect(context).to include('[참고자료 1]')
        expect(context).to include('[참고자료 2]')
        expect(context).to include('규정: 학사 규정 (ACAD-001)')
        expect(context).to include('조문: 제1조 목적')
        expect(context).to include('조문: 제2조 적용범위')
        expect(context).to include('관련도: 95.0%')
        expect(context).to include('관련도: 87.0%')
      end
    end
    
    context '검색 결과가 없는 경우' do
      it '기본 메시지를 반환한다' do
        context = job.send(:build_context, [])
        expect(context).to eq('관련 규정을 찾을 수 없습니다.')
      end
    end
  end
  
  describe '#build_prompt' do
    let(:job) { described_class.new }
    let(:user_question) { '학사 규정에 대해 알려주세요' }
    let(:context) { '규정: 학사 규정 (ACAD-001)' }
    
    it '사용자 질문과 컨텍스트를 포함한 프롬프트를 생성한다' do
      prompt = job.send(:build_prompt, user_question, context)
      
      expect(prompt).to include('당신은 대학 규정 전문가입니다')
      expect(prompt).to include("사용자 질문: #{user_question}")
      expect(prompt).to include("관련 규정 자료:\n#{context}")
      expect(prompt).to include('답변 지침:')
      expect(prompt).to include('제공된 규정 자료를 바탕으로 답변하세요')
    end
  end
end