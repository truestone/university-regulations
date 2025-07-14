# frozen_string_literal: true

require 'rails_helper'

RSpec.describe QuestionEmbeddingService, type: :service do
  let(:service) { described_class.new(question: question) }
  let(:question) { "대학교 등록금 납부 기한은 언제인가요?" }

  before do
    # OpenAI API 스텁
    stub_openai_embeddings_api
  end

  describe 'validations' do
    it 'validates presence of question' do
      service = described_class.new(question: '')
      expect(service).not_to be_valid
      expect(service.errors[:question]).to include("can't be blank")
    end

    it 'validates minimum length of question' do
      service = described_class.new(question: 'ab')
      expect(service).not_to be_valid
      expect(service.errors[:question]).to include('is too short (minimum is 3 characters)')
    end

    it 'validates maximum length of question' do
      long_question = 'a' * 1001
      service = described_class.new(question: long_question)
      expect(service).not_to be_valid
      expect(service.errors[:question]).to include('is too long (maximum is 1000 characters)')
    end
  end

  describe '.generate_embedding' do
    it 'generates embedding for valid question' do
      result = described_class.generate_embedding(question)
      
      expect(result).to be_a(Hash)
      expect(result[:embedding]).to be_present
      expect(result[:embedding].length).to eq(1536)
      expect(result[:preprocessed_text]).to be_present
      expect(result[:token_count]).to be > 0
      expect(result[:original_question]).to eq(question)
    end

    it 'returns nil for invalid question' do
      result = described_class.generate_embedding('')
      expect(result).to be_nil
    end
  end

  describe '#process' do
    it 'processes question successfully' do
      result = service.process
      
      expect(result).to be_a(Hash)
      expect(result[:embedding]).to be_an(Array)
      expect(result[:embedding].length).to eq(1536)
      expect(result[:preprocessed_text]).to be_present
      expect(result[:token_count]).to be_positive
    end

    it 'handles OpenAI API errors' do
      stub_openai_embeddings_api_error(status: 429, message: 'Rate limit exceeded')
      
      expect {
        service.process
      }.to raise_error(StandardError, /Rate limit exceeded/)
    end
  end

  describe '#preprocess_text' do
    it 'normalizes whitespace' do
      service = described_class.new(question: "대학교   등록금    납부")
      preprocessed = service.send(:preprocess_text, service.question)
      expect(preprocessed).not_to include('   ')
    end

    it 'removes special characters while preserving Korean and basic punctuation' do
      service = described_class.new(question: "대학교 등록금@#$ 납부?")
      preprocessed = service.send(:preprocess_text, service.question)
      expect(preprocessed).to include('대학교 등록금')
      expect(preprocessed).to include('?')
      expect(preprocessed).not_to include('@#$')
    end

    it 'adds question format if missing' do
      service = described_class.new(question: "대학교 등록금 납부 기한")
      preprocessed = service.send(:preprocess_text, service.question)
      expect(preprocessed).to include('규정은 무엇인가요?')
    end

    it 'preserves existing question format' do
      service = described_class.new(question: "대학교 등록금 납부 기한은 언제인가요?")
      preprocessed = service.send(:preprocess_text, service.question)
      expect(preprocessed).to eq("대학교 등록금 납부 기한은 언제인가요?")
    end
  end

  describe '#remove_stopwords' do
    it 'removes Korean stopwords from long sentences' do
      long_question = "대학교 등록금은 언제까지 납부를 해야 하는가요"
      service = described_class.new(question: long_question)
      service.preprocessed_text = long_question
      
      result = service.send(:remove_stopwords, long_question)
      expect(result.split.length).to be < long_question.split.length
    end

    it 'preserves short sentences' do
      short_question = "등록금 납부 기한"
      service = described_class.new(question: short_question)
      
      result = service.send(:remove_stopwords, short_question)
      expect(result).to eq(short_question)
    end
  end

  describe '#estimate_token_count' do
    it 'estimates token count for Korean text' do
      korean_text = "대학교 등록금 납부 기한"
      service = described_class.new(question: korean_text)
      
      token_count = service.send(:estimate_token_count, korean_text)
      expect(token_count).to be > 0
      expect(token_count).to be <= korean_text.length
    end

    it 'estimates token count for mixed text' do
      mixed_text = "University 등록금 payment deadline"
      service = described_class.new(question: mixed_text)
      
      token_count = service.send(:estimate_token_count, mixed_text)
      expect(token_count).to be > 0
    end
  end

  describe '#analyze_question_type' do
    it 'identifies what questions' do
      service = described_class.new(question: "무엇인가요?")
      expect(service.send(:analyze_question_type)).to eq(:what)
    end

    it 'identifies how questions' do
      service = described_class.new(question: "어떻게 해야 하나요?")
      expect(service.send(:analyze_question_type)).to eq(:how)
    end

    it 'identifies when questions' do
      service = described_class.new(question: "언제까지 납부해야 하나요?")
      expect(service.send(:analyze_question_type)).to eq(:when)
    end

    it 'defaults to general for other questions' do
      service = described_class.new(question: "등록금 관련 규정")
      expect(service.send(:analyze_question_type)).to eq(:general)
    end
  end

  describe '#analyze_question_complexity' do
    it 'identifies simple questions' do
      service = described_class.new(question: "등록금?")
      service.preprocessed_text = "등록금?"
      expect(service.send(:analyze_question_complexity)).to eq(:simple)
    end

    it 'identifies medium questions' do
      service = described_class.new(question: "대학교 등록금 납부 기한은?")
      service.preprocessed_text = "대학교 등록금 납부 기한은?"
      expect(service.send(:analyze_question_complexity)).to eq(:medium)
    end

    it 'identifies complex questions' do
      long_question = "대학교 학부생 등록금 납부 기한과 연체료 계산 방법은 무엇인가요?"
      service = described_class.new(question: long_question)
      service.preprocessed_text = long_question
      expect(service.send(:analyze_question_complexity)).to eq(:complex)
    end
  end

  describe '#generate_metadata' do
    it 'generates comprehensive metadata' do
      service.preprocessed_text = "대학교 등록금 납부 기한은 언제인가요?"
      service.token_count = 10
      
      metadata = service.send(:generate_metadata)
      
      expect(metadata).to include(:question_type, :complexity, :token_count, :preprocessed, :processed_at)
      expect(metadata[:question_type]).to eq(:when)
      expect(metadata[:complexity]).to eq(:medium)
      expect(metadata[:token_count]).to eq(10)
      expect(metadata[:processed_at]).to be_a(Time)
    end
  end
end