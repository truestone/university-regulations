# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Messages Turbo Streams', type: :view do
  let(:conversation) { create(:conversation) }
  let(:user_message) { create(:message, conversation: conversation, role: 'user') }
  let(:ai_message) { create(:message, conversation: conversation, role: 'assistant') }

  describe 'create.turbo_stream.erb' do
    before do
      assign(:message, user_message)
      assign(:conversation, conversation)
    end

    it 'renders turbo stream for message creation' do
      render template: 'messages/create.turbo_stream.erb'
      
      expect(rendered).to include('turbo-stream action="append" target="messages"')
      expect(rendered).to include('turbo-stream action="replace" target="message-form"')
      expect(rendered).to include('turbo-stream action="update" target="loadingIndicator"')
    end
  end

  describe 'ai_response.turbo_stream.erb' do
    before do
      assign(:message, ai_message)
      assign(:conversation, conversation)
    end

    it 'renders turbo stream for AI response' do
      render template: 'messages/ai_response.turbo_stream.erb'
      
      expect(rendered).to include('turbo-stream action="append" target="messages"')
      expect(rendered).to include('turbo-stream action="replace" target="message-form"')
      expect(rendered).to include('turbo-stream action="update" target="loadingIndicator"')
    end
  end

  describe '_loading_indicator.html.erb' do
    it 'renders loading indicator with animation' do
      render partial: 'messages/loading_indicator'
      
      expect(rendered).to include('AI가 답변을 생성 중입니다')
      expect(rendered).to include('animate-bounce')
      expect(rendered).to include('id="ai-loading"')
    end
  end
end