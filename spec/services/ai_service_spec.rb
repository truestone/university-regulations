require 'rails_helper'

RSpec.describe AiService, type: :service do
  let!(:openai_setting) { create(:ai_setting, provider: 'openai', is_active: true, api_key: 'test-key') }
  let!(:anthropic_setting) { create(:ai_setting, provider: 'anthropic', is_active: true, api_key: 'test-key') }
  let!(:google_setting) { create(:ai_setting, provider: 'google', is_active: true, api_key: 'test-key') }
  let!(:inactive_setting) { create(:ai_setting, provider: 'openai', is_active: false) }

  describe '.get_active_setting' do
    it 'returns active setting for specified provider' do
      setting = AiService.get_active_setting('openai')
      expect(setting).to eq(openai_setting)
    end

    it 'returns first active setting when no provider specified' do
      setting = AiService.get_active_setting
      expect(setting).to be_present
      expect(setting.is_active).to be true
    end

    it 'returns nil for inactive provider' do
      inactive_setting.update(provider: 'test_provider')
      setting = AiService.get_active_setting('test_provider')
      expect(setting).to be_nil
    end
  end

  describe '.available_providers' do
    it 'returns list of active providers' do
      providers = AiService.available_providers
      expect(providers).to include('openai', 'anthropic', 'google')
      expect(providers).not_to include('inactive')
    end
  end

  describe '.can_use_provider?' do
    it 'returns true for active provider with valid settings' do
      expect(AiService.can_use_provider?('openai')).to be true
    end

    it 'returns false for inactive provider' do
      openai_setting.update(is_active: false)
      expect(AiService.can_use_provider?('openai')).to be false
    end

    it 'returns false for non-existent provider' do
      expect(AiService.can_use_provider?('nonexistent')).to be false
    end

    it 'returns false for provider over critical budget' do
      openai_setting.update(budget_limit: 10, usage_this_month: 20)
      expect(AiService.can_use_provider?('openai')).to be false
    end
  end

  describe '.get_embedding' do
    let(:text) { 'Test text for embedding' }

    before do
      allow_any_instance_of(OpenaiService).to receive(:get_embedding).and_return({
        embedding: Array.new(1536, 0.1),
        tokens_used: 10,
        cost: 0.0001,
        model: 'text-embedding-3-small'
      })
    end

    it 'gets embedding from OpenAI by default' do
      result = AiService.get_embedding(text)
      
      expect(result[:embedding]).to be_present
      expect(result[:tokens_used]).to eq(10)
      expect(result[:cost]).to eq(0.0001)
    end

    it 'gets embedding from specified provider' do
      result = AiService.get_embedding(text, provider: 'openai')
      
      expect(result[:embedding]).to be_present
      expect(result[:model]).to eq('text-embedding-3-small')
    end

    it 'raises error for inactive provider' do
      openai_setting.update(is_active: false)
      
      expect {
        AiService.get_embedding(text, provider: 'openai')
      }.to raise_error(/No active AI setting found/)
    end

    it 'falls back to OpenAI for Anthropic embeddings' do
      expect {
        AiService.get_embedding(text, provider: 'anthropic')
      }.not_to raise_error
    end
  end

  describe '.chat_completion' do
    let(:messages) { [{ role: 'user', content: 'Hello' }] }

    before do
      allow_any_instance_of(OpenaiService).to receive(:chat_completion).and_return({
        content: 'Hello! How can I help you?',
        input_tokens: 5,
        output_tokens: 8,
        total_tokens: 13,
        cost: 0.0002,
        model: 'gpt-4o-mini'
      })
    end

    it 'gets chat completion from available provider' do
      result = AiService.chat_completion(messages)
      
      expect(result[:content]).to be_present
      expect(result[:total_tokens]).to eq(13)
      expect(result[:cost]).to eq(0.0002)
    end

    it 'gets chat completion from specified provider' do
      result = AiService.chat_completion(messages, provider: 'openai')
      
      expect(result[:content]).to be_present
      expect(result[:model]).to eq('gpt-4o-mini')
    end

    it 'raises error for inactive provider' do
      openai_setting.update(is_active: false)
      anthropic_setting.update(is_active: false)
      google_setting.update(is_active: false)
      
      expect {
        AiService.chat_completion(messages, provider: 'openai')
      }.to raise_error(/No active AI setting found/)
    end
  end

  describe '.estimate_cost' do
    it 'estimates cost for OpenAI embedding' do
      cost = AiService.estimate_cost('test text', provider: 'openai', operation: 'embedding')
      expect(cost).to be >= 0
    end

    it 'estimates cost for chat completion' do
      cost = AiService.estimate_cost('test text', provider: 'openai', operation: 'chat')
      expect(cost).to be >= 0
    end

    it 'returns 0 for unsupported provider' do
      cost = AiService.estimate_cost('test text', provider: 'unsupported')
      expect(cost).to eq(0)
    end
  end

  describe '.update_usage' do
    it 'updates usage for provider' do
      expect {
        AiService.update_usage('openai', 0.05)
      }.to change { openai_setting.reload.usage_this_month }.by(0.05)
    end

    it 'triggers budget warning when exceeded' do
      openai_setting.update(budget_limit: 0.01, usage_this_month: 0.005)
      
      expect_any_instance_of(BudgetWarningService).to receive(:send_warning)
      AiService.update_usage('openai', 0.01)
    end

    it 'does nothing for non-existent provider' do
      expect {
        AiService.update_usage('nonexistent', 0.05)
      }.not_to change { AiSetting.sum(:usage_this_month) }
    end
  end
end