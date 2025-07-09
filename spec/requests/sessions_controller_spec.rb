require 'rails_helper'

RSpec.describe SessionsController, type: :request do
  let(:user) { create(:user, email: 'admin@example.com', password: 'SecurePass123!') }

  describe 'GET /login' do
    it 'displays the login form' do
      get login_path
      expect(response).to have_http_status(:success)
      expect(response.body).to include('관리자 로그인')
    end

    context 'when user is already logged in' do
      before do
        post login_path, params: { email: user.email, password: 'SecurePass123!' }
      end

      it 'redirects to admin dashboard' do
        get login_path
        expect(response).to redirect_to(admin_dashboard_path)
      end
    end
  end

  describe 'POST /login' do
    context 'with valid credentials' do
      it 'logs in the user and redirects to dashboard' do
        post login_path, params: { email: user.email, password: 'SecurePass123!' }
        
        expect(response).to redirect_to(admin_dashboard_path)
        expect(session[:user_id]).to eq(user.id)
        expect(session[:login_time]).to be_present
        expect(flash[:notice]).to eq('성공적으로 로그인되었습니다.')
      end

      it 'updates last login time' do
        expect {
          post login_path, params: { email: user.email, password: 'SecurePass123!' }
        }.to change { user.reload.last_login_at }
      end

      it 'resets failed attempts' do
        user.update(failed_attempts: 3)
        post login_path, params: { email: user.email, password: 'SecurePass123!' }
        
        expect(user.reload.failed_attempts).to eq(0)
      end
    end

    context 'with invalid credentials' do
      it 'renders login form with error message' do
        post login_path, params: { email: user.email, password: 'wrongpassword' }
        
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include('이메일 또는 비밀번호가 올바르지 않습니다.')
        expect(session[:user_id]).to be_nil
      end

      it 'increments failed attempts' do
        expect {
          post login_path, params: { email: user.email, password: 'wrongpassword' }
        }.to change { user.reload.failed_attempts }.by(1)
      end
    end

    context 'with blank credentials' do
      it 'renders login form with validation error' do
        post login_path, params: { email: '', password: '' }
        
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include('이메일과 비밀번호를 입력해주세요.')
      end
    end

    context 'with locked account' do
      before do
        user.update(failed_attempts: 5, locked_until: 1.hour.from_now)
      end

      it 'prevents login and shows lock message' do
        post login_path, params: { email: user.email, password: 'SecurePass123!' }
        
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include('계정이 잠겨있습니다.')
        expect(session[:user_id]).to be_nil
      end
    end

    context 'with non-existent email' do
      it 'renders login form with error message' do
        post login_path, params: { email: 'nonexistent@example.com', password: 'password' }
        
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include('이메일 또는 비밀번호가 올바르지 않습니다.')
      end
    end
  end

  describe 'DELETE /logout' do
    before do
      post login_path, params: { email: user.email, password: 'SecurePass123!' }
    end

    it 'logs out the user and redirects to login' do
      delete logout_path
      
      expect(response).to redirect_to(login_path)
      expect(session[:user_id]).to be_nil
      expect(session[:login_time]).to be_nil
      expect(flash[:notice]).to eq('성공적으로 로그아웃되었습니다.')
    end

    it 'resets the session' do
      session[:custom_data] = 'test'
      delete logout_path
      
      expect(session[:custom_data]).to be_nil
    end
  end

  describe 'session security' do
    it 'handles case-insensitive email login' do
      post login_path, params: { email: user.email.upcase, password: 'SecurePass123!' }
      
      expect(response).to redirect_to(admin_dashboard_path)
      expect(session[:user_id]).to eq(user.id)
    end

    it 'strips whitespace from email' do
      post login_path, params: { email: "  #{user.email}  ", password: 'SecurePass123!' }
      
      expect(response).to redirect_to(admin_dashboard_path)
      expect(session[:user_id]).to eq(user.id)
    end
  end
end