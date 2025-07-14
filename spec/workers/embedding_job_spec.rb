# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EmbeddingJob, type: :worker do
  let(:regulation) { create(:regulation) }
  let(:article) { create(:article, regulation: regulation, content: "테스트 조문 내용") }
  
  before do
    # OpenAI API 호출을 스텁으로 대체
    allow_any_instance_of(OpenAI::Client).to receive(:embeddings).and_return({
      'data' => [
        {
          'embedding' => Array.new(1536, 0.1) # 고정된 1536차원 벡터
        }
      ]
    })
  end

  describe '#perform' do
    context '임베딩이 없는 조문의 경우' do
      it '임베딩을 생성하고 저장한다' do
        expect(article.embedding).to be_nil
        
        EmbeddingJob.new.perform(article.id)
        
        article.reload
        expect(article.embedding).to be_present
        expect(article.embedding.length).to eq(1536)
        expect(article.embedding_updated_at).to be_present
      end
    end

    context '이미 최신 임베딩이 있는 경우' do
      before do
        article.update!(
          embedding: Array.new(1536, 0.2),
          embedding_updated_at: 1.hour.ago
        )
        # updated_at을 embedding_updated_at보다 이전으로 설정
        article.update_column(:updated_at, 2.hours.ago)
      end

      it '임베딩 생성을 스킵한다' do
        original_embedding = article.embedding
        original_updated_at = article.embedding_updated_at
        
        expect_any_instance_of(OpenAI::Client).not_to receive(:embeddings)
        
        EmbeddingJob.new.perform(article.id)
        
        article.reload
        expect(article.embedding).to eq(original_embedding)
        expect(article.embedding_updated_at).to eq(original_updated_at)
      end
    end

    context '조문이 업데이트된 경우' do
      before do
        article.update!(
          embedding: Array.new(1536, 0.2),
          embedding_updated_at: 2.hours.ago
        )
        # updated_at을 embedding_updated_at보다 나중으로 설정
        article.update_column(:updated_at, 1.hour.ago)
      end

      it '임베딩을 재생성한다' do
        expect_any_instance_of(OpenAI::Client).to receive(:embeddings).once
        
        EmbeddingJob.new.perform(article.id)
        
        article.reload
        expect(article.embedding).to eq(Array.new(1536, 0.1))
        expect(article.embedding_updated_at).to be > 1.hour.ago
      end
    end

    context 'OpenAI API 호출이 실패하는 경우' do
      before do
        allow_any_instance_of(OpenAI::Client).to receive(:embeddings).and_raise(StandardError.new("API Error"))
      end

      it '예외를 발생시켜 Sidekiq 재시도를 유발한다' do
        expect {
          EmbeddingJob.new.perform(article.id)
        }.to raise_error(StandardError, "API Error")
      end
    end

    context '잘못된 임베딩 응답을 받는 경우' do
      before do
        allow_any_instance_of(OpenAI::Client).to receive(:embeddings).and_return({
          'data' => [
            {
              'embedding' => Array.new(100, 0.1) # 잘못된 차원
            }
          ]
        })
      end

      it '예외를 발생시킨다' do
        expect {
          EmbeddingJob.new.perform(article.id)
        }.to raise_error(/Invalid embedding response/)
      end
    end
  end

  describe '#build_prompt' do
    let(:job) { EmbeddingJob.new }
    
    it '조문의 전체 컨텍스트를 포함한 프롬프트를 생성한다' do
      prompt = job.send(:build_prompt, article)
      
      expect(prompt).to include(article.regulation.title)
      expect(prompt).to include(article.regulation.regulation_code)
      expect(prompt).to include("제#{article.number}조")
      expect(prompt).to include(article.title)
      expect(prompt).to include(article.content)
    end
  end
end