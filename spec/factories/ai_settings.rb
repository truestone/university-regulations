FactoryBot.define do
  factory :ai_setting do
    provider { "MyString" }
    api_key { "MyString" }
    model_id { "MyString" }
    monthly_budget { "9.99" }
    usage_this_month { "9.99" }
    is_active { false }
    last_used_at { "2025-07-07 04:10:08" }
  end
end
