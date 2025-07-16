class Admin::DashboardController < ApplicationController
  before_action :require_admin
  before_action :check_session_expiry

  def index
    @current_user = current_user
    
    # 기본 통계 정보
    @stats = {
      total_regulations: Regulation.count,
      total_articles: Article.count,
      total_users: User.count,
      recent_logins: User.where('last_login_at > ?', 7.days.ago).count
    }
    
    # 최근 활동
    @recent_activities = []
  end

  def embedding
    @current_user = current_user
    
    # Embedding statistics
    @embedding_stats = {
      total_articles: Article.count,
      articles_with_embedding: Article.where.not(embedding: nil).count,
      articles_without_embedding: Article.where(embedding: nil).count,
      recently_updated: Article.where("embedding_updated_at > ?", 24.hours.ago).count
    }
    
    # Sidekiq queue statistics
    require "sidekiq/api"
    @sidekiq_stats = Sidekiq::Stats.new
    @embedding_queue = Sidekiq::Queue.new("embedding")
    @failed_jobs = Sidekiq::FailedSet.new
    @embedding_failures = @failed_jobs.select { |job| job.klass == "EmbeddingJob" }
    
    # Recent embedding updates
    @recent_embeddings = Article.where.not(embedding_updated_at: nil)
                                .order(embedding_updated_at: :desc)
                                .limit(10)
                                .includes(:regulation)
    
    # Embedding progress
    @embedding_progress = calculate_embedding_progress
  end

  private

  def calculate_embedding_progress
    total = Article.count
    return 0 if total == 0
    
    with_embedding = Article.where.not(embedding: nil).count
    ((with_embedding.to_f / total) * 100).round(2)
  end
end
