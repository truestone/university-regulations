require 'rails_helper'

RSpec.describe 'Authentication Flow', type: :system do
  let(:admin_user) { create(:user, email: 'admin@example.com', password: 'SecurePass123!', role: 'admin') }
  let(:super_admin_user) { create(:user, email: 'superadmin@example.com', password: 'SecurePass123!', role: 'super_admin') }

  before do
    driven_by(:rack_test)
  end

  describe 'Login Flow' do
    it 'allows admin to login with valid credentials' do
      visit login_path
      
      expect(page).to have_content('관리자 로그인')
      expect(page).to have_field('이메일 주소')
      expect(page).to have_field('비밀번호')
      
      fill_in '이메일 주소', with: admin_user.email
      fill_in '비밀번호', with: 'SecurePass123!'
      click_button '로그인'
      
      expect(page).to have_current_path(admin_dashboard_path)
      expect(page).to have_content('성공적으로 로그인되었습니다.')
      expect(page).to have_content("안녕하세요, #{admin_user.name}님")
    end

    it 'shows error message for invalid credentials' do
      visit login_path
      
      fill_in '이메일 주소', with: admin_user.email
      fill_in '비밀번호', with: 'wrongpassword'
      click_button '로그인'
      
      expect(page).to have_current_path(login_path)
      expect(page).to have_content('이메일 또는 비밀번호가 올바르지 않습니다.')
    end

    it 'shows error message for blank credentials' do
      visit login_path
      
      click_button '로그인'
      
      expect(page).to have_current_path(login_path)
      expect(page).to have_content('이메일과 비밀번호를 입력해주세요.')
    end

    it 'redirects authenticated users away from login page' do
      # Login first
      visit login_path
      fill_in '이메일 주소', with: admin_user.email
      fill_in '비밀번호', with: 'SecurePass123!'
      click_button '로그인'
      
      # Try to visit login page again
      visit login_path
      expect(page).to have_current_path(admin_dashboard_path)
    end
  end

  describe 'Dashboard Access' do
    context 'when authenticated' do
      before do
        visit login_path
        fill_in '이메일 주소', with: admin_user.email
        fill_in '비밀번호', with: 'SecurePass123!'
        click_button '로그인'
      end

      it 'displays dashboard with user information' do
        expect(page).to have_content('관리자 대시보드')
        expect(page).to have_content("안녕하세요, #{admin_user.name}님")
        expect(page).to have_content('(admin)')
      end

      it 'displays system statistics' do
        expect(page).to have_content('총 사용자')
        expect(page).to have_content('총 편')
        expect(page).to have_content('총 규정')
        expect(page).to have_content('최근 로그인')
      end

      it 'displays system information' do
        expect(page).to have_content('시스템 정보')
        expect(page).to have_content('Rails 버전')
        expect(page).to have_content('Ruby 버전')
        expect(page).to have_content('환경')
      end
    end

    context 'when not authenticated' do
      it 'redirects to login page' do
        visit admin_dashboard_path
        
        expect(page).to have_current_path(login_path)
        expect(page).to have_content('로그인이 필요합니다.')
      end
    end
  end

  describe 'Logout Flow' do
    before do
      visit login_path
      fill_in '이메일 주소', with: admin_user.email
      fill_in '비밀번호', with: 'SecurePass123!'
      click_button '로그인'
    end

    it 'allows user to logout' do
      expect(page).to have_link('로그아웃')
      
      accept_confirm do
        click_link '로그아웃'
      end
      
      expect(page).to have_current_path(login_path)
      expect(page).to have_content('성공적으로 로그아웃되었습니다.')
    end

    it 'prevents access to protected pages after logout' do
      accept_confirm do
        click_link '로그아웃'
      end
      
      visit admin_dashboard_path
      expect(page).to have_current_path(login_path)
      expect(page).to have_content('로그인이 필요합니다.')
    end
  end

  describe 'Role-based Access' do
    it 'displays correct role badge for admin' do
      visit login_path
      fill_in '이메일 주소', with: admin_user.email
      fill_in '비밀번호', with: 'SecurePass123!'
      click_button '로그인'
      
      expect(page).to have_content('(admin)')
    end

    it 'displays correct role badge for super admin' do
      visit login_path
      fill_in '이메일 주소', with: super_admin_user.email
      fill_in '비밀번호', with: 'SecurePass123!'
      click_button '로그인'
      
      expect(page).to have_content('(super_admin)')
    end
  end

  describe 'Account Security' do
    it 'handles account lockout after multiple failed attempts' do
      visit login_path
      
      # Attempt login 5 times with wrong password
      5.times do
        fill_in '이메일 주소', with: admin_user.email
        fill_in '비밀번호', with: 'wrongpassword'
        click_button '로그인'
      end
      
      # 6th attempt should show lockout message
      fill_in '이메일 주소', with: admin_user.email
      fill_in '비밀번호', with: 'SecurePass123!'
      click_button '로그인'
      
      expect(page).to have_content('계정이 잠겨있습니다.')
    end
  end

  describe 'UI Elements' do
    before do
      visit login_path
    end

    it 'has proper form structure' do
      expect(page).to have_css('form')
      expect(page).to have_field('email', type: 'email')
      expect(page).to have_field('password', type: 'password')
      expect(page).to have_button('로그인')
    end

    it 'has proper styling classes' do
      expect(page).to have_css('.min-h-screen')
      expect(page).to have_css('.bg-gray-50')
      expect(page).to have_css('input[required]', count: 2)
    end

    it 'displays proper placeholders' do
      expect(page).to have_field(placeholder: '이메일 주소')
      expect(page).to have_field(placeholder: '비밀번호')
    end
  end

  describe 'Responsive Design', js: true do
    before do
      driven_by(:selenium_chrome_headless)
    end

    it 'works on mobile viewport' do
      page.driver.browser.manage.window.resize_to(375, 667) # iPhone size
      
      visit login_path
      
      expect(page).to have_content('관리자 로그인')
      expect(page).to have_field('이메일 주소')
      expect(page).to have_field('비밀번호')
    end

    it 'works on tablet viewport' do
      page.driver.browser.manage.window.resize_to(768, 1024) # iPad size
      
      visit login_path
      
      expect(page).to have_content('관리자 로그인')
      expect(page).to have_field('이메일 주소')
      expect(page).to have_field('비밀번호')
    end
  end
end