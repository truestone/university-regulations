class Admin::DashboardController < ApplicationController
  before_action :require_admin
  before_action :check_session_expiry
  
  def index
    @current_user = current_user
    @stats = {
      total_users: User.count,
      total_editions: Edition.count,
      total_chapters: Chapter.count,
      total_regulations: Regulation.count,
      total_articles: Article.count,
      total_clauses: Clause.count,
      recent_logins: User.where('last_login_at > ?', 24.hours.ago).count
    }
    
    @recent_users = User.order(last_login_at: :desc).limit(5)
    @system_info = {
      rails_version: Rails.version,
      ruby_version: RUBY_VERSION,
      environment: Rails.env
    }
  end
end
