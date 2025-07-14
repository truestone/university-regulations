# frozen_string_literal: true

require 'rails_helper'
require 'rake'

RSpec.describe 'embedding rake tasks', type: :task do
  before do
    Rails.application.load_tasks if Rake::Task.tasks.empty?
    
    # Sidekiq 테스트 모드 설정
    require 'sidekiq/testing'
    Sidekiq::Testing.fake!
  end

  after do
    Sidekiq::Worker.clear_all
  end

  let(:regulation) { create(:regulation) }
  let!(:articles) { create_list(:article, 3, regulation: regulation) }

  describe 'embedding:generate_all' do
    it '모든 조문에 대해 임베딩 생성 작업을 큐에 추가한다' do
      expect {
        Rake::Task['embedding:generate_all'].invoke
      }.to change(EmbeddingJob.jobs, :size).by(3)
    end

    it '이미 최신 임베딩이 있는 조문은 스킵한다' do
      # 첫 번째 조문에 최신 임베딩 설정
      articles.first.update_columns(
        embedding: Array.new(1536, 0.1),
        embedding_updated_at: 1.hour.from_now
      )

      expect {
        Rake::Task['embedding:generate_all'].invoke
      }.to change(EmbeddingJob.jobs, :size).by(2)
    end
  end

  describe 'embedding:generate_missing' do
    before do
      # 두 번째 조문에만 임베딩 설정
      articles.second.update_columns(embedding: Array.new(1536, 0.1))
    end

    it '임베딩이 없는 조문에만 작업을 큐에 추가한다' do
      expect {
        Rake::Task['embedding:generate_missing'].invoke
      }.to change(EmbeddingJob.jobs, :size).by(2)
    end
  end

  describe 'embedding:update_modified' do
    before do
      # 모든 조문에 임베딩 설정
      articles.each do |article|
        article.update_columns(
          embedding: Array.new(1536, 0.1),
          embedding_updated_at: 2.hours.ago
        )
      end
      
      # 첫 번째 조문만 최근에 수정됨으로 설정
      articles.first.update_columns(updated_at: 1.hour.ago)
    end

    it '최근 수정된 조문에만 작업을 큐에 추가한다' do
      expect {
        Rake::Task['embedding:update_modified'].invoke
      }.to change(EmbeddingJob.jobs, :size).by(1)
    end
  end

  describe 'embedding:status' do
    before do
      articles.first.update_columns(embedding: Array.new(1536, 0.1))
    end

    it '임베딩 상태를 출력한다' do
      expect {
        Rake::Task['embedding:status'].invoke
      }.to output(/임베딩 생성 상태/).to_stdout
    end
  end

  describe 'embedding:test' do
    it '특정 조문에 대해 임베딩을 동기적으로 생성한다' do
      # OpenAI API 스텁
      allow_any_instance_of(OpenAI::Client).to receive(:embeddings).and_return({
        'data' => [{ 'embedding' => Array.new(1536, 0.1) }]
      })

      expect {
        Rake::Task['embedding:test'].invoke(articles.first.id)
      }.to change { articles.first.reload.embedding }.from(nil)
    end
  end

  describe 'embedding:cleanup' do
    it 'Sidekiq 실패 큐를 정리한다' do
      expect {
        Rake::Task['embedding:cleanup'].invoke
      }.to output(/임베딩 작업 정리/).to_stdout
    end
  end

  describe 'embedding:help' do
    it '도움말을 출력한다' do
      expect {
        Rake::Task['embedding:help'].invoke
      }.to output(/임베딩 관련 Rake 태스크/).to_stdout
    end
  end
end