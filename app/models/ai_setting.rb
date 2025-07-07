class AiSetting < ApplicationRecord
  validates :provider, presence: true, inclusion: { in: %w[openai anthropic google] }
  validates :model_id, presence: true
  validates :monthly_budget, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :usage_this_month, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :provider, uniqueness: { scope: :model_id }
  
  scope :active, -> { where(is_active: true) }
  scope :by_provider, ->(provider) { where(provider: provider) }
  scope :within_budget, -> { where('usage_this_month < monthly_budget') }
  
  def budget_exceeded?
    usage_this_month >= monthly_budget
  end
  
  def budget_remaining
    monthly_budget - usage_this_month
  end
  
  def usage_percentage
    return 0 if monthly_budget.zero?
    (usage_this_month / monthly_budget * 100).round(2)
  end
  
  def can_use?
    is_active? && !budget_exceeded? && api_key.present?
  end
end
