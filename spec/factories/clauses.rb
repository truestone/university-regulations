FactoryBot.define do
  factory :clause do
    article { nil }
    number { 1 }
    content { "MyText" }
    clause_type { "MyString" }
    sort_order { 1 }
    is_active { false }
  end
end
