FactoryBot.define do
  factory :message do
    conversation { nil }
    role { "MyString" }
    content { "MyText" }
    tokens_used { 1 }
    created_at { "2025-07-07 04:09:40" }
  end
end
