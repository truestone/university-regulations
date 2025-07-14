# frozen_string_literal: true

# Sidekiq Web UI 접근 권한 제어
class AdminConstraint
  def matches?(request)
    return false unless request.session[:user_id]
    
    user = User.find_by(id: request.session[:user_id])
    user&.admin?
  end
end