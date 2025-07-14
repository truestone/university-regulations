# frozen_string_literal: true

FactoryBot.define do
  factory :search_query do
    query_text { "대학교 등록금 납부 기한은 언제인가요?" }
    embedding { Array.new(1536, 0.1) }
    results_count { 5 }
    response_time_ms { 150 }
    metadata do
      {
        question_type: 'when',
        complexity: 'medium',
        token_count: 10,
        preprocessed: false
      }
    end

    trait :successful do
      error_message { nil }
      results_count { rand(1..10) }
      response_time_ms { rand(50..300) }
    end

    trait :failed do
      error_message { "OpenAI API Error: Rate limit exceeded" }
      results_count { 0 }
      response_time_ms { rand(1000..3000) }
    end

    trait :recent do
      created_at { rand(1.hour..1.day).seconds.ago }
    end

    trait :old do
      created_at { rand(1.week..1.month).seconds.ago }
    end

    trait :simple_question do
      query_text { "등록금?" }
      metadata do
        {
          question_type: 'general',
          complexity: 'simple',
          token_count: 2,
          preprocessed: true
        }
      end
    end

    trait :complex_question do
      query_text { "대학교 학부생 등록금 납부 기한과 연체료 계산 방법 및 분할납부 가능 여부에 대한 상세한 규정은 무엇인가요?" }
      metadata do
        {
          question_type: 'what',
          complexity: 'very_complex',
          token_count: 25,
          preprocessed: false
        }
      end
    end

    trait :what_question do
      query_text { "장학금 신청 자격은 무엇인가요?" }
      metadata do
        {
          question_type: 'what',
          complexity: 'medium',
          token_count: 8,
          preprocessed: false
        }
      end
    end

    trait :how_question do
      query_text { "휴학 신청은 어떻게 하나요?" }
      metadata do
        {
          question_type: 'how',
          complexity: 'medium',
          token_count: 7,
          preprocessed: false
        }
      end
    end

    trait :when_question do
      query_text { "수강신청은 언제까지 가능한가요?" }
      metadata do
        {
          question_type: 'when',
          complexity: 'medium',
          token_count: 8,
          preprocessed: false
        }
      end
    end

    trait :with_ip_and_session do
      ip_address { "192.168.1.#{rand(1..254)}" }
      user_agent { "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36" }
      session_id { SecureRandom.hex(16) }
    end

    trait :high_performance do
      response_time_ms { rand(10..50) }
      results_count { rand(8..15) }
    end

    trait :low_performance do
      response_time_ms { rand(500..2000) }
      results_count { rand(0..2) }
    end
  end
end