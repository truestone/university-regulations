class HomeController < ApplicationController
  def index
    # 홈페이지 - 로그인하지 않은 사용자를 위한 페이지
    if user_signed_in?
      redirect_to admin_dashboard_path
    else
      # 로그인하지 않은 사용자는 로그인 페이지로 리다이렉트
      redirect_to login_path
    end
  end
end
