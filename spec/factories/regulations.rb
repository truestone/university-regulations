FactoryBot.define do
  factory :regulation do
    chapter { nil }
    number { 1 }
    title { "MyString" }
    content { "MyText" }
    regulation_code { "MyString" }
    status { "MyString" }
    sort_order { 1 }
    is_active { false }
  end
end
