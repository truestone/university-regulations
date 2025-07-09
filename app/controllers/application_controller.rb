class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern
  
  # CSRF 보호
  protect_from_forgery with: :exception
  
  # 현재 로그인한 사용자 조회
  def current_user
    return @current_user if defined?(@current_user)
    
    @current_user = session[:user_id] ? User.find_by(id: session[:user_id]) : nil
    
    # 세션이 만료되었거나 사용자가 삭제된 경우
    if @current_user.nil? && session[:user_id]
      reset_session
    end
    
    @current_user
  end
  helper_method :current_user
  
  # 로그인 여부 확인
  def user_signed_in?
    current_user.present?
  end
  helper_method :user_signed_in?
  
  # 관리자 권한 확인
  def require_admin
    unless current_user&.admin? || current_user&.super_admin?
      flash[:alert] = '관리자 권한이 필요합니다.'
      redirect_to login_path
    end
  end
  
  # 슈퍼 관리자 권한 확인
  def require_super_admin
    unless current_user&.super_admin?
      flash[:alert] = '슈퍼 관리자 권한이 필요합니다.'
      redirect_to admin_dashboard_path
    end
  end
  
  # 인증 필요
  def require_authentication
    unless user_signed_in?
      flash[:alert] = '로그인이 필요합니다.'
      redirect_to login_path
    end
  end
  
  # 세션 만료 확인 (4시간)
  def check_session_expiry
    if session[:login_time] && session[:login_time] < 4.hours.ago
      reset_session
      flash[:alert] = '세션이 만료되었습니다. 다시 로그인해주세요.'
      redirect_to login_path
    else
      # 세션 시간 갱신
      session[:login_time] = Time.current if user_signed_in?
    end
  end
  
  private
  
  # 에러 처리
  def handle_unauthorized
    if request.xhr?
      render json: { error: 'Unauthorized' }, status: :unauthorized
    else
      flash[:alert] = '권한이 없습니다.'
      redirect_to login_path
    end
  end
end