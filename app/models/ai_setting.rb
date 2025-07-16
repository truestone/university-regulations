class AiSetting < ApplicationRecord
  validates :provider, presence: true, inclusion: { in: %w[openai anthropic google] }
  validates :model_id, presence: true
  validates :api_key, presence: true
  validates :monthly_budget, presence: true, numericality: { greater_than: 0 }
  validates :usage_this_month, presence: true, numericality: { greater_than_or_equal_to: 0 }
  
  scope :active, -> { where(is_active: true) }
  scope :by_provider, ->(provider) { where(provider: provider) }
  scope :within_budget, -> { where('usage_this_month <= monthly_budget') }
  scope :over_budget, -> { where('usage_this_month > monthly_budget') }
  
  def budget_exceeded?
    usage_this_month > monthly_budget
  end
  
  def usage_percentage
    return 0 if monthly_budget.zero?
    (usage_this_month / monthly_budget * 100).round(2)
  end
  
  def remaining_budget
    [monthly_budget - usage_this_month, 0].max
  end
  
  def can_use?
    is_active? && api_key.present? && !critically_over_budget?
  end
  
  def critically_over_budget?
    usage_this_month > (monthly_budget * 1.5)
  end
  
  def provider_display_name
    case provider
    when 'openai'
      'OpenAI'
    when 'anthropic'
      'Anthropic (Claude)'
    when 'google'
      'Google AI (Gemini)'
    else
      provider.humanize
    end
  end
  
  def reset_monthly_usage!
    update!(usage_this_month: 0, last_warning_sent_at: nil)
  end
  
  def add_usage(cost)
    increment!(:usage_this_month, cost)
    
    # Check if we need to send a warning
    if budget_exceeded? && (last_warning_sent_at.nil? || last_warning_sent_at < 1.day.ago)
      BudgetWarningService.new(self).send_warning
    end
  end
  
  # Class method to reset all monthly usage (for scheduled job)
  def self.reset_all_monthly_usage!
    where('usage_this_month > 0').find_each(&:reset_monthly_usage!)
  end
end