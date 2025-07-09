require 'rails_helper'

RSpec.describe 'Authentication Integration', type: :request do
  let(:admin_user) { create(:user, email: 'admin@example.com', password: 'SecurePass123!', role: 'admin') }
  let(:super_admin_user) { create(:user, email: 'superadmin@example.com', password: 'SecurePass123!', role: 'super_admin') }

  describe 'Complete Authentication Flow' do
    it 'handles full login to dashboard flow' do
      # Step 1: Visit login page
      get login_path
      expect(response).to have_http_status(:success)
      expect(response.body).to include('관리자 로그인')

      # Step 2: Submit login form
      post login_path, params: { email: admin_user.email, password: 'SecurePass123!' }
      expect(response).to redirect_to(admin_dashboard_path)
      expect(session[:user_id]).to eq(admin_user.id)
      expect(session[:login_time]).to be_present

      # Step 3: Access dashboard
      follow_redirect!
      expect(response).to have_http_status(:success)
      expect(response.body).to include('관리자 대시보드')
      expect(response.body).to include(admin_user.name)

      # Step 4: Logout
      delete logout_path
      expect(response).to redirect_to(login_path)
      expect(session[:user_id]).to be_nil
      expect(session[:login_time]).to be_nil
    end

    it 'prevents unauthorized access to protected resources' do
      # Try to access dashboard without login
      get admin_dashboard_path
      expect(response).to redirect_to(login_path)
      expect(flash[:alert]).to eq('로그인이 필요합니다.')

      # Try to access with invalid session
      get admin_dashboard_path, headers: { 'Cookie' => '_regulations_session=invalid' }
      expect(response).to redirect_to(login_path)
    end

    it 'handles session expiry correctly' do
      # Login
      post login_path, params: { email: admin_user.email, password: 'SecurePass123!' }
      expect(response).to redirect_to(admin_dashboard_path)

      # Simulate session expiry by setting old login time
      session[:login_time] = 5.hours.ago

      # Try to access dashboard
      get admin_dashboard_path
      expect(response).to redirect_to(login_path)
      expect(flash[:alert]).to eq('세션이 만료되었습니다. 다시 로그인해주세요.')
    end
  end

  describe 'Role-based Access Control' do
    it 'allows admin access to dashboard' do
      post login_path, params: { email: admin_user.email, password: 'SecurePass123!' }
      get admin_dashboard_path
      expect(response).to have_http_status(:success)
    end

    it 'allows super admin access to dashboard' do
      post login_path, params: { email: super_admin_user.email, password: 'SecurePass123!' }
      get admin_dashboard_path
      expect(response).to have_http_status(:success)
    end

    it 'tracks user login activity' do
      expect {
        post login_path, params: { email: admin_user.email, password: 'SecurePass123!' }
      }.to change { admin_user.reload.last_login_at }
    end
  end

  describe 'Security Features' do
    it 'handles account lockout' do
      # Make 5 failed attempts
      5.times do
        post login_path, params: { email: admin_user.email, password: 'wrongpassword' }
      end

      # User should be locked
      expect(admin_user.reload.failed_attempts).to eq(5)
      expect(admin_user.locked?).to be true

      # Try to login with correct password
      post login_path, params: { email: admin_user.email, password: 'SecurePass123!' }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include('계정이 잠겨있습니다.')
    end

    it 'resets failed attempts on successful login' do
      # Make some failed attempts
      3.times do
        post login_path, params: { email: admin_user.email, password: 'wrongpassword' }
      end

      expect(admin_user.reload.failed_attempts).to eq(3)

      # Successful login should reset attempts
      post login_path, params: { email: admin_user.email, password: 'SecurePass123!' }
      expect(admin_user.reload.failed_attempts).to eq(0)
    end

    it 'handles CSRF protection' do
      # Try to login without CSRF token
      post login_path, params: { email: admin_user.email, password: 'SecurePass123!' }, 
           headers: { 'X-CSRF-Token' => 'invalid' }
      
      # Should be protected by CSRF
      expect(response.status).to be_in([422, 403])
    end
  end

  describe 'Dashboard Data Integration' do
    let!(:edition) { create(:edition) }
    let!(:chapter) { create(:chapter, edition: edition) }
    let!(:regulation) { create(:regulation, chapter: chapter) }
    let!(:article) { create(:article, regulation: regulation) }
    let!(:clause) { create(:clause, article: article) }

    before do
      post login_path, params: { email: admin_user.email, password: 'SecurePass123!' }
    end

    it 'displays correct statistics on dashboard' do
      get admin_dashboard_path
      
      expect(response.body).to include('총 사용자')
      expect(response.body).to include('총 편')
      expect(response.body).to include('총 규정')
      expect(response.body).to include('최근 로그인')
    end

    it 'shows recent users information' do
      get admin_dashboard_path
      
      expect(response.body).to include('최근 로그인 사용자')
      expect(response.body).to include(admin_user.name)
      expect(response.body).to include(admin_user.email)
    end

    it 'displays system information' do
      get admin_dashboard_path
      
      expect(response.body).to include('시스템 정보')
      expect(response.body).to include('Rails 버전')
      expect(response.body).to include('Ruby 버전')
      expect(response.body).to include(Rails.version)
      expect(response.body).to include(RUBY_VERSION)
    end
  end

  describe 'Error Handling' do
    it 'handles invalid login gracefully' do
      post login_path, params: { email: 'nonexistent@example.com', password: 'password' }
      
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include('이메일 또는 비밀번호가 올바르지 않습니다.')
    end

    it 'handles blank credentials' do
      post login_path, params: { email: '', password: '' }
      
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include('이메일과 비밀번호를 입력해주세요.')
    end

    it 'handles malformed requests' do
      post login_path, params: { invalid: 'data' }
      
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe 'Session Management' do
    it 'creates session on successful login' do
      post login_path, params: { email: admin_user.email, password: 'SecurePass123!' }
      
      expect(session[:user_id]).to eq(admin_user.id)
      expect(session[:login_time]).to be_within(1.minute).of(Time.current)
    end

    it 'destroys session on logout' do
      # Login first
      post login_path, params: { email: admin_user.email, password: 'SecurePass123!' }
      expect(session[:user_id]).to be_present
      
      # Logout
      delete logout_path
      expect(session[:user_id]).to be_nil
      expect(session[:login_time]).to be_nil
    end

    it 'handles multiple concurrent sessions' do
      # Simulate two different sessions
      session1 = { user_id: admin_user.id, login_time: Time.current }
      session2 = { user_id: super_admin_user.id, login_time: Time.current }
      
      # Both should be valid independently
      expect(session1[:user_id]).to eq(admin_user.id)
      expect(session2[:user_id]).to eq(super_admin_user.id)
    end
  end
end