# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RagPromptService, type: :service do
  let(:question) { "대학교 등록금 납부 기한은 언제인가요?" }
  let(:search_results) do
    [
      {
        id: 1,
        title: "등록금 납부",
        content: "등록금은 매 학기 개시 30일 전까지 납부하여야 한다.",
        number: 15,
        regulation_title: "학사 규정",
        regulation_code: "ACAD-001",
        similarity: 0.95
      },
      {
        id: 2,
        title: "연체료",
        content: "등록금 납부 기한을 초과한 경우 연체료가 부과된다.",
        number: 16,
        regulation_title: "학사 규정",
        regulation_code: "ACAD-001",
        similarity: 0.85
      }
    ]
  end

  let(:service) { described_class.new(question: question, search_results: search_results.to_json) }

  describe 'validations' do
    it 'validates presence of question' do
      service = described_class.new(question: '', search_results: search_results.to_json)
      expect(service).not_to be_valid
      expect(service.errors[:question]).to include("can't be blank")
    end

    it 'validates question length' do
      service = described_class.new(question: 'ab', search_results: search_results.to_json)
      expect(service).not_to be_valid
      expect(service.errors[:question]).to include('is too short (minimum is 3 characters)')

      long_question = 'a' * 501
      service = described_class.new(question: long_question, search_results: search_results.to_json)
      expect(service).not_to be_valid
      expect(service.errors[:question]).to include('is too long (maximum is 500 characters)')
    end

    it 'validates presence of search_results' do
      service = described_class.new(question: question, search_results: '')
      expect(service).not_to be_valid
      expect(service.errors[:search_results]).to include("can't be blank")
    end

    it 'validates max_context_tokens range' do
      service = described_class.new(
        question: question,
        search_results: search_results.to_json,
        max_context_tokens: 50
      )
      expect(service).not_to be_valid
      expect(service.errors[:max_context_tokens]).to include('must be greater than 100')
    end

    it 'validates response_format inclusion' do
      service = described_class.new(
        question: question,
        search_results: search_results.to_json,
        response_format: 'invalid'
      )
      expect(service).not_to be_valid
      expect(service.errors[:response_format]).to include('is not included in the list')
    end
  end

  describe '.generate_prompt' do
    it 'generates a complete prompt structure' do
      result = described_class.generate_prompt(
        question: question,
        search_results: search_results
      )

      expect(result).to be_a(Hash)
      expect(result).to have_key(:system_prompt)
      expect(result).to have_key(:user_prompt)
      expect(result).to have_key(:context)
      expect(result).to have_key(:metadata)
    end

    it 'returns nil for invalid input' do
      result = described_class.generate_prompt(
        question: '',
        search_results: search_results
      )

      expect(result).to be_nil
    end
  end

  describe '#build_prompt' do
    it 'builds a valid prompt structure' do
      result = service.build_prompt

      expect(result[:system_prompt]).to include('대학교 규정 전문가')
      expect(result[:user_prompt]).to include(question)
      expect(result[:context]).to be_a(Hash)
      expect(result[:metadata]).to be_a(Hash)
    end
  end

  describe '#build_system_prompt' do
    it 'includes basic guidelines' do
      system_prompt = service.send(:build_system_prompt)

      expect(system_prompt).to include('답변 원칙')
      expect(system_prompt).to include('제공된 규정 내용만을 근거로')
      expect(system_prompt).to include('관련 조문 번호와 규정명')
    end

    it 'includes safety guidelines when safety_mode is true' do
      service.safety_mode = true
      system_prompt = service.send(:build_system_prompt)

      expect(system_prompt).to include('안전 지침')
      expect(system_prompt).to include('개인정보')
    end

    it 'includes response format instructions' do
      service.response_format = 'structured'
      system_prompt = service.send(:build_system_prompt)

      expect(system_prompt).to include('답변 요약')
      expect(system_prompt).to include('상세 설명')
      expect(system_prompt).to include('관련 규정')
    end
  end

  describe '#process_search_results' do
    it 'processes and sorts search results by similarity' do
      processed = service.send(:process_search_results)

      expect(processed).to be_an(Array)
      expect(processed.length).to eq(2)
      expect(processed.first['similarity']).to be >= processed.last['similarity']
    end

    it 'respects token limits' do
      service.max_context_tokens = 200  # Very low limit
      processed = service.send(:process_search_results)

      # Should include fewer results due to token limit
      expect(processed.length).to be <= 2
    end
  end

  describe '#format_single_result' do
    let(:result) { search_results.first }

    it 'formats a single search result correctly' do
      formatted = service.send(:format_single_result, result, 1)

      expect(formatted).to include('1.')
      expect(formatted).to include(result[:regulation_title])
      expect(formatted).to include(result[:regulation_code])
      expect(formatted).to include("제#{result[:number]}조")
      expect(formatted).to include(result[:title])
      expect(formatted).to include(result[:content])
    end

    it 'includes similarity score when include_sources is true' do
      service.include_sources = true
      formatted = service.send(:format_single_result, result)

      expect(formatted).to include('유사도: 95.0%')
    end

    it 'excludes similarity score when include_sources is false' do
      service.include_sources = false
      formatted = service.send(:format_single_result, result)

      expect(formatted).not_to include('유사도')
    end
  end

  describe '#summarize_content' do
    it 'returns content as-is if short enough' do
      short_content = "짧은 내용입니다."
      result = service.send(:summarize_content, short_content)
      expect(result).to eq(short_content)
    end

    it 'summarizes long content' do
      long_content = "첫 번째 문장입니다. 두 번째 문장입니다. 세 번째 문장입니다. " * 20
      result = service.send(:summarize_content, long_content)
      
      expect(result.length).to be < long_content.length
      expect(result).to include('첫 번째 문장')
    end
  end

  describe '#estimate_tokens' do
    it 'estimates tokens for Korean text' do
      korean_text = "대학교 등록금 납부 기한"
      tokens = service.send(:estimate_tokens, korean_text)
      
      expect(tokens).to be > 0
      expect(tokens).to be <= korean_text.length
    end

    it 'estimates tokens for mixed text' do
      mixed_text = "University 등록금 payment 기한"
      tokens = service.send(:estimate_tokens, mixed_text)
      
      expect(tokens).to be > 0
    end
  end

  describe '#mask_pii' do
    it 'masks email addresses' do
      text_with_email = "문의사항은 admin@university.edu로 연락하세요"
      masked = service.send(:mask_pii, text_with_email)
      
      expect(masked).to include('[이메일]')
      expect(masked).not_to include('admin@university.edu')
    end

    it 'masks phone numbers' do
      text_with_phone = "연락처: 02-1234-5678"
      masked = service.send(:mask_pii, text_with_phone)
      
      expect(masked).to include('[전화번호]')
      expect(masked).not_to include('02-1234-5678')
    end

    it 'does not mask when safety_mode is false' do
      service.safety_mode = false
      text_with_email = "문의사항은 admin@university.edu로 연락하세요"
      masked = service.send(:mask_pii, text_with_email)
      
      expect(masked).to eq(text_with_email)
    end
  end

  describe '#evaluate_prompt_quality' do
    it 'evaluates prompt quality metrics' do
      quality = service.send(:evaluate_prompt_quality)

      expect(quality).to have_key(:context_coverage)
      expect(quality).to have_key(:token_efficiency)
      expect(quality).to have_key(:relevance_score)
      expect(quality).to have_key(:completeness_score)
      
      expect(quality[:context_coverage]).to be_a(Numeric)
      expect(quality[:token_efficiency]).to be_a(Numeric)
      expect(quality[:relevance_score]).to be_a(Numeric)
      expect(quality[:completeness_score]).to be_a(Numeric)
    end
  end

  describe 'different response formats' do
    it 'generates brief format instructions' do
      service.response_format = 'brief'
      system_prompt = service.send(:build_system_prompt)
      
      expect(system_prompt).to include('간결하고 핵심적인')
      expect(system_prompt).to include('1-2문장')
    end

    it 'generates detailed format instructions' do
      service.response_format = 'detailed'
      system_prompt = service.send(:build_system_prompt)
      
      expect(system_prompt).to include('상세하고 구체적인')
      expect(system_prompt).to include('관련 조문과 근거')
    end

    it 'generates structured format instructions' do
      service.response_format = 'structured'
      system_prompt = service.send(:build_system_prompt)
      
      expect(system_prompt).to include('답변 요약')
      expect(system_prompt).to include('상세 설명')
      expect(system_prompt).to include('관련 규정')
      expect(system_prompt).to include('추가 안내')
    end
  end
end