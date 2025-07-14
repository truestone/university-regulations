# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Article, 'after_commit hooks', type: :model do
  let(:regulation) { create(:regulation) }
  
  before do
    # Sidekiq 테스트 모드 설정
    require 'sidekiq/testing'
    Sidekiq::Testing.fake!
  end

  after do
    Sidekiq::Worker.clear_all
  end

  describe 'after_commit :enqueue_embedding_job' do
    context '새로운 조문 생성 시' do
      it 'EmbeddingJob을 큐에 추가한다' do
        expect {
          create(:article, regulation: regulation)
        }.to change(EmbeddingJob.jobs, :size).by(1)
      end
    end

    context '조문 업데이트 시' do
      let!(:article) { create(:article, regulation: regulation) }

      it '내용이 변경되면 EmbeddingJob을 큐에 추가한다' do
        Sidekiq::Worker.clear_all
        
        expect {
          article.update!(content: "Updated content")
        }.to change(EmbeddingJob.jobs, :size).by(1)
      end

      it '임베딩이 최신 상태면 EmbeddingJob을 큐에 추가하지 않는다' do
        # 임베딩을 최신 상태로 설정
        article.update_columns(
          embedding: Array.new(1536, 0.1),
          embedding_updated_at: 1.hour.from_now
        )
        
        Sidekiq::Worker.clear_all
        
        expect {
          article.update!(title: "Title only change")
        }.not_to change(EmbeddingJob.jobs, :size)
      end
    end

    context 'needs_embedding_update? method' do
      let(:article) { create(:article, regulation: regulation) }

      it '임베딩이 없으면 true를 반환한다' do
        article.update_columns(embedding: nil, embedding_updated_at: nil)
        expect(article.needs_embedding_update?).to be true
      end

      it '임베딩 업데이트 시간이 없으면 true를 반환한다' do
        article.update_columns(embedding: Array.new(1536, 0.1), embedding_updated_at: nil)
        expect(article.needs_embedding_update?).to be true
      end

      it '업데이트 시간이 임베딩 업데이트 시간보다 나중이면 true를 반환한다' do
        article.update_columns(
          embedding: Array.new(1536, 0.1),
          embedding_updated_at: 1.hour.ago,
          updated_at: 30.minutes.ago
        )
        expect(article.needs_embedding_update?).to be true
      end

      it '임베딩이 최신 상태면 false를 반환한다' do
        article.update_columns(
          embedding: Array.new(1536, 0.1),
          embedding_updated_at: 1.hour.ago,
          updated_at: 2.hours.ago
        )
        expect(article.needs_embedding_update?).to be false
      end
    end

    context 'transaction rollback' do
      it '트랜잭션이 롤백되면 EmbeddingJob이 큐에 추가되지 않는다' do
        expect {
          Article.transaction do
            create(:article, regulation: regulation)
            raise ActiveRecord::Rollback
          end
        }.not_to change(EmbeddingJob.jobs, :size)
      end
    end
  end
end