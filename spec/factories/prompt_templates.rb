# frozen_string_literal: true

FactoryBot.define do
  factory :prompt_template do
    sequence(:name) { |n| "template_#{n}" }
    template_type { 'system' }
    content { 'Hello {{name}}, welcome to {{system}}!' }
    version { 1 }
    description { 'Test template' }
    is_active { true }
    created_by { 'test_user' }

    trait :system_template do
      template_type { 'system' }
      content do
        <<~CONTENT
          You are a university regulation expert.
          
          Guidelines:
          {{safety_guidelines}}
          
          Format:
          {{response_format}}
        CONTENT
      end
    end

    trait :user_template do
      template_type { 'user' }
      content do
        <<~CONTENT
          ## Context:
          {{context}}
          
          ## Question:
          {{question}}
          
          Please provide an accurate answer based on the regulations above.
        CONTENT
      end
    end

    trait :context_template do
      template_type { 'context' }
      content do
        <<~CONTENT
          ### {{regulation_title}} ({{regulation_code}})
          **Article {{article_number}}: {{article_title}}**
          
          {{content}}
          
          *Similarity: {{similarity}}%*
        CONTENT
      end
    end

    trait :inactive do
      is_active { false }
    end

    trait :version_2 do
      version { 2 }
    end

    trait :with_metadata do
      metadata do
        {
          author: 'admin',
          tags: ['regulation', 'qa'],
          last_tested: 1.day.ago,
          performance_score: 85.5
        }
      end
    end
  end
end