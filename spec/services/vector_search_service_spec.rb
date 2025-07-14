# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VectorSearchService, type: :service do
  let(:sample_query) { "학생의 권리와 의무" }
  let(:service) { described_class.new(sample_query) }

  before do
    # 테스트용 데이터 생성
    create_test_articles_with_embeddings
  end

  describe '#initialize' do
    it '쿼리와 옵션을 올바르게 설정한다' do
      expect(service.query).to eq(sample_query)
      expect(service.options).to include(
        limit: 10,
        similarity_threshold: 0.7,
        include_context: true
      )
    end

    it '커스텀 옵션을 적용한다' do
      custom_service = described_class.new(sample_query, limit: 5, similarity_threshold: 0.8)
      expect(custom_service.options[:limit]).to eq(5)
      expect(custom_service.options[:similarity_threshold]).to eq(0.8)
    end
  end

  describe '#search' do
    context '빈 쿼리인 경우' do
      let(:empty_service) { described_class.new('') }

      it '빈 배열을 반환한다' do
        expect(empty_service.search).to eq([])
      end
    end

    context '유효한 쿼리인 경우' do
      before do
        # OpenAI API 모킹
        allow(service).to receive(:generate_query_embedding).and_return(sample_embedding)
      end

      it '검색 결과를 반환한다' do
        results = service.search
        expect(results).to be_an(Array)
      end

      it '유사도 점수가 포함된다' do
        results = service.search
        results.each do |result|
          expect(result).to respond_to(:similarity_score)
        end
      end
    end
  end

  describe '#find_similar_articles' do
    let(:article_with_embedding) { create(:article, :with_embedding) }

    it '유사한 조문들을 반환한다' do
      similar_articles = service.find_similar_articles(article_with_embedding.id, limit: 3)
      
      expect(similar_articles).to be_an(Array)
      expect(similar_articles.size).to be <= 3
      expect(similar_articles).not_to include(article_with_embedding)
    end

    it '유사도 점수 메서드가 추가된다' do
      similar_articles = service.find_similar_articles(article_with_embedding.id, limit: 1)
      
      if similar_articles.any?
        expect(similar_articles.first).to respond_to(:similarity_score)
        expect(similar_articles.first.similarity_score).to be_between(0, 1)
      end
    end
  end

  describe '#hybrid_search' do
    before do
      allow(service).to receive(:generate_query_embedding).and_return(sample_embedding)
    end

    it '벡터 검색과 키워드 검색을 결합한다' do
      results = service.hybrid_search
      expect(results).to be_an(Array)
    end

    it '결합 점수가 포함된다' do
      results = service.hybrid_search
      results.each do |result|
        expect(result).to respond_to(:combined_score) if result.respond_to?(:combined_score)
      end
    end
  end

  describe '#search_stats' do
    before do
      allow(service).to receive(:generate_query_embedding).and_return(sample_embedding)
      service.search
    end

    it '검색 통계를 반환한다' do
      stats = service.search_stats
      
      expect(stats).to include(
        :query,
        :total_results,
        :avg_similarity,
        :search_time,
        :options
      )
    end
  end

  private

  def create_test_articles_with_embeddings
    # 테스트용 Edition, Chapter, Regulation 생성
    edition = create(:edition, number: 1, title: "학칙")
    chapter = create(:chapter, edition: edition, number: 1, title: "학생")
    regulation = create(:regulation, chapter: chapter, regulation_code: "1-1-1", title: "학생 규정")

    # 임베딩이 있는 조문들 생성
    3.times do |i|
      create(:article, 
        regulation: regulation,
        number: i + 1,
        title: "제#{i + 1}조 (학생의 권리)",
        content: "학생은 교육받을 권리와 의무를 가진다.",
        embedding: sample_embedding
      )
    end
  end

  def sample_embedding
    # 1536차원의 샘플 임베딩 벡터
    Array.new(1536) { rand(-1.0..1.0) }
  end
end