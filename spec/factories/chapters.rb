FactoryBot.define do
  factory :chapter do
    edition { nil }
    number { 1 }
    title { "MyString" }
    description { "MyText" }
    sort_order { 1 }
    is_active { false }
  end
end
