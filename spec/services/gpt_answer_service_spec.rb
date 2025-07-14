# frozen_string_literal: true

require 'rails_helper'

RSpec.describe GptAnswerService, type: :service do
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
      }
    ]
  end

  let(:service) { described_class.new(question: question, search_results: search_results.to_json) }

  before do
    # OpenAI API 스텁
    stub_openai_chat_completions_api({
      'choices' => [
        {
          'message' => {
            'role' => 'assistant',
            'content' => '대학교 등록금은 매 학기 개시 30일 전까지 납부하여야 합니다. 이는 학사 규정 제15조에 명시되어 있습니다.'
          },
          'finish_reason' => 'stop',
          'index' => 0
        }
      ],
      'model' => 'gpt-4',
      'usage' => {
        'prompt_tokens' => 100,
        'completion_tokens' => 50,
        'total_tokens' => 150
      }
    })
  end

  describe 'validations' do
    it 'validates presence of question' do
      service = described_class.new(question: '', search_results: search_results.to_json)
      expect(service).not_to be_valid
      expect(service.errors[:question]).to include("can't be blank")
    end

    it 'validates presence of search_results' do
      service = described_class.new(question: question, search_results: '')
      expect(service).not_to be_valid
      expect(service.errors[:search_results]).to include("can't be blank")
    end

    it 'validates model inclusion' do
      service = described_class.new(
        question: question,
        search_results: search_results.to_json,
        model: 'invalid-model'
      )
      expect(service).not_to be_valid
      expect(service.errors[:model]).to include('is not included in the list')
    end

    it 'validates temperature range' do
      service = described_class.new(
        question: question,
        search_results: search_results.to_json,
        temperature: 3.0
      )
      expect(service).not_to be_valid
      expect(service.errors[:temperature]).to include('must be less than or equal to 2')
    end

    it 'validates max_tokens range' do
      service = described_class.new(
        question: question,
        search_results: search_results.to_json,
        max_tokens: 0
      )
      expect(service).not_to be_valid
      expect(service.errors[:max_tokens]).to include('must be greater than 0')
    end
  end

  describe '.generate_answer' do
    it 'generates a complete answer structure' do
      result = described_class.generate_answer(
        question: question,
        search_results: search_results
      )

      expect(result).to be_a(Hash)
      expect(result).to have_key(:answer)
      expect(result).to have_key(:sources)
      expect(result).to have_key(:metadata)
      
      expect(result[:answer]).to be_a(String)
      expect(result[:sources]).to be_an(Array)
      expect(result[:metadata]).to be_a(Hash)
    end

    it 'returns nil for invalid input' do
      result = described_class.generate_answer(
        question: '',
        search_results: search_results
      )

      expect(result).to be_nil
    end
  end

  describe '#generate' do
    it 'generates answer successfully' do
      result = service.generate

      expect(result[:answer]).to include('등록금')
      expect(result[:answer]).to include('30일 전')
      expect(result[:sources]).to be_an(Array)
      expect(result[:metadata][:model]).to eq('gpt-4')
      expect(result[:metadata][:execution_time_ms]).to be > 0
    end

    it 'handles API errors gracefully' do
      stub_openai_chat_completions_api_error(status: 429, message: 'Rate limit exceeded')

      result = service.generate

      expect(result).to have_key(:error)
      expect(result[:answer]).to include('일시적인 문제')
      expect(result[:error][:message]).to include('Rate limit exceeded')
    end
  end

  describe '#calculate_max_context_tokens' do
    it 'calculates appropriate context token limit' do
      service.model = 'gpt-4'
      service.max_tokens = 1000
      
      max_context = service.send(:calculate_max_context_tokens)
      
      expect(max_context).to be > 0
      expect(max_context).to be <= 3000
    end

    it 'adjusts for different models' do
      service.model = 'gpt-4-turbo'
      turbo_limit = service.send(:calculate_max_context_tokens)
      
      service.model = 'gpt-3.5-turbo'
      standard_limit = service.send(:calculate_max_context_tokens)
      
      expect(turbo_limit).to be >= standard_limit
    end
  end

  describe '#validate_response_quality' do
    it 'validates minimum response length' do
      expect(Rails.logger).to receive(:warn).with(/too short/)
      
      service.send(:validate_response_quality, 'short')
    end

    it 'detects forbidden phrases' do
      expect(Rails.logger).to receive(:warn).with(/forbidden phrase/)
      
      service.send(:validate_response_quality, '저는 AI입니다. 확실하지 않습니다.')
    end

    it 'checks for regulation references' do
      expect(Rails.logger).to receive(:warn).with(/lacks regulation references/)
      
      service.send(:validate_response_quality, '일반적인 답변입니다.')
    end

    it 'passes validation for good responses' do
      expect(Rails.logger).not_to receive(:warn)
      
      service.send(:validate_response_quality, '제15조에 따르면 등록금은 30일 전까지 납부해야 합니다.')
    end
  end

  describe '#post_process_content' do
    it 'removes unnecessary prefixes' do
      content_with_prefix = '답변: 등록금은 30일 전까지 납부해야 합니다.'
      processed = service.send(:post_process_content, content_with_prefix)
      
      expect(processed).not_to start_with('답변:')
      expect(processed).to include('등록금은 30일 전까지')
    end

    it 'cleans markdown formatting' do
      content_with_markdown = '***강조*** 텍스트\n\n\n\n여러 줄바꿈'
      processed = service.send(:post_process_content, content_with_markdown)
      
      expect(processed).to include('**강조**')
      expect(processed).not_to include('***')
      expect(processed).not_to include("\n\n\n")
    end
  end

  describe '#calculate_quality_score' do
    let(:prompt_data) do
      {
        context: {
          used_results: 2,
          max_similarity: 0.95
        }
      }
    end

    it 'calculates quality score based on multiple factors' do
      good_response = '제15조에 따르면 **등록금은 매 학기 개시 30일 전까지** 납부하여야 합니다. 상세한 내용은 학사 규정을 참조하시기 바랍니다.'
      
      score = service.send(:calculate_quality_score, good_response, prompt_data)
      
      expect(score).to be > 50
      expect(score).to be <= 100
    end

    it 'gives lower scores for poor responses' do
      poor_response = '잘 모르겠습니다.'
      
      score = service.send(:calculate_quality_score, poor_response, prompt_data)
      
      expect(score).to be < 50
    end
  end

  describe '#extract_sources_from_search_results' do
    it 'extracts source information correctly' do
      sources = service.send(:extract_sources_from_search_results)
      
      expect(sources).to be_an(Array)
      expect(sources.length).to eq(1)
      
      source = sources.first
      expect(source).to have_key(:id)
      expect(source).to have_key(:title)
      expect(source).to have_key(:regulation_title)
      expect(source).to have_key(:similarity)
    end

    it 'limits sources to maximum of 5' do
      large_results = Array.new(10) { |i| search_results.first.merge(id: i) }
      service.search_results = large_results.to_json
      
      sources = service.send(:extract_sources_from_search_results)
      
      expect(sources.length).to eq(5)
    end
  end

  describe '.generate_ab_test_answers' do
    it 'generates two different answer variants' do
      result = described_class.generate_ab_test_answers(
        question: question,
        search_results: search_results
      )

      expect(result).to have_key(:variant_a)
      expect(result).to have_key(:variant_b)
      expect(result).to have_key(:test_metadata)
      
      expect(result[:variant_a][:metadata][:temperature]).to eq(0.3)
      expect(result[:variant_b][:metadata][:temperature]).to eq(0.7)
      
      expect(result[:test_metadata][:test_id]).to be_present
    end
  end

  describe 'error handling' do
    it 'handles empty API responses' do
      stub_openai_chat_completions_api({
        'choices' => [
          {
            'message' => {
              'role' => 'assistant',
              'content' => ''
            }
          }
        ]
      })

      result = service.generate

      expect(result).to have_key(:error)
      expect(result[:answer]).to include('일시적인 문제')
    end

    it 'handles malformed API responses' do
      stub_openai_chat_completions_api({
        'choices' => []
      })

      result = service.generate

      expect(result).to have_key(:error)
      expect(result[:error][:type]).to eq('RuntimeError')
    end
  end
end

# OpenAI Chat Completions API 스텁 헬퍼
def stub_openai_chat_completions_api(response = nil)
  response ||= {
    'choices' => [
      {
        'message' => {
          'role' => 'assistant',
          'content' => 'This is a test response from GPT.'
        },
        'finish_reason' => 'stop',
        'index' => 0
      }
    ],
    'model' => 'gpt-4',
    'usage' => {
      'prompt_tokens' => 20,
      'completion_tokens' => 10,
      'total_tokens' => 30
    }
  }

  stub_request(:post, 'https://api.openai.com/v1/chat/completions')
    .to_return(
      status: 200,
      body: response.to_json,
      headers: { 'Content-Type' => 'application/json' }
    )
end

def stub_openai_chat_completions_api_error(status: 500, message: 'Internal Server Error')
  stub_request(:post, 'https://api.openai.com/v1/chat/completions')
    .to_return(
      status: status,
      body: { error: { message: message } }.to_json,
      headers: { 'Content-Type' => 'application/json' }
    )
end