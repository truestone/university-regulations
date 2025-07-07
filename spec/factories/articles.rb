FactoryBot.define do
  factory :article do
    regulation { nil }
    number { 1 }
    title { "MyString" }
    content { "MyText" }
    sort_order { 1 }
    is_active { false }
  end
end
