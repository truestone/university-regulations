class SessionsController < ApplicationController
  before_action :redirect_if_authenticated, only: [:new, :create]
  
  def new
    # 로그인 폼 표시
  end

  def create
    email = params[:email]&.downcase&.strip
    password = params[:password]
    
    if email.blank? || password.blank?
      flash.now[:alert] = '이메일과 비밀번호를 입력해주세요.'
      render :new, status: :unprocessable_entity
      return
    end

    user = User.find_by(email: email)
    
    if user&.locked?
      flash.now[:alert] = '계정이 잠겨있습니다. 잠시 후 다시 시도해주세요.'
      render :new, status: :unprocessable_entity
      return
    end

    authenticated_user = User.authenticate(email, password)
    
    if authenticated_user
      # 로그인 성공
      authenticated_user.reset_failed_attempts!
      authenticated_user.update_last_login!
      
      session[:user_id] = authenticated_user.id
      session[:login_time] = Time.current
      
      flash[:notice] = '성공적으로 로그인되었습니다.'
      redirect_to admin_dashboard_path
    else
      # 로그인 실패
      user&.increment_failed_attempts!
      
      flash.now[:alert] = '이메일 또는 비밀번호가 올바르지 않습니다.'
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    if current_user
      session.delete(:user_id)
      session.delete(:login_time)
      reset_session
      
      flash[:notice] = '성공적으로 로그아웃되었습니다.'
    end
    
    redirect_to login_path
  end
  
  private
  
  def redirect_if_authenticated
    redirect_to admin_dashboard_path if current_user
  end
end