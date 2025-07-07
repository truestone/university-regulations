require 'rails_helper'

RSpec.describe AiSetting, type: :model do
  describe 'validations' do
    it 'validates presence of required fields' do
      setting = AiSetting.new
      expect(setting).not_to be_valid
      expect(setting.errors[:provider]).to include("can't be blank")
      expect(setting.errors[:model_id]).to include("can't be blank")
    end

    it 'validates provider inclusion' do
      setting = AiSetting.new(provider: 'invalid_provider')
      expect(setting).not_to be_valid
      expect(setting.errors[:provider]).to include('is not included in the list')
    end

    it 'requires api_key when active' do
      setting = AiSetting.new(provider: 'openai', model_id: 'gpt-4', is_active: true, monthly_budget: 100, usage_this_month: 0)
      expect(setting).not_to be_valid
      expect(setting.errors[:api_key]).to include('must be present when setting is active')
    end

    it 'validates usage does not exceed budget' do
      setting = AiSetting.new(provider: 'openai', model_id: 'gpt-4', monthly_budget: 100, usage_this_month: 150)
      expect(setting).not_to be_valid
      expect(setting.errors[:usage_this_month]).to include('cannot exceed monthly budget')
    end
  end

  describe 'methods' do
    let(:setting) { AiSetting.new(is_active: true, monthly_budget: 100, usage_this_month: 50, api_key: 'test-key') }
    let(:exceeded_setting) { AiSetting.new(monthly_budget: 100, usage_this_month: 100) }

    it 'calculates budget status correctly' do
      expect(setting.budget_exceeded?).to be false
      expect(exceeded_setting.budget_exceeded?).to be true
    end

    it 'calculates usage percentage' do
      expect(setting.usage_percentage).to eq(50.0)
    end

    it 'determines if can be used' do
      expect(setting.can_use?).to be true
    end
  end
end
