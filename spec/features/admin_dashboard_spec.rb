require 'rails_helper'

RSpec.describe 'Admin Dashboard', type: :feature do
  let(:admin_user) { create(:user, email: 'admin@example.com', password: 'SecurePass123!', role: 'admin') }
  let(:super_admin_user) { create(:user, email: 'superadmin@example.com', password: 'SecurePass123!', role: 'super_admin') }
  
  # Create some test data
  let!(:edition) { create(:edition) }
  let!(:chapter) { create(:chapter, edition: edition) }
  let!(:regulation) { create(:regulation, chapter: chapter) }
  let!(:article) { create(:article, regulation: regulation) }
  let!(:clause) { create(:clause, article: article) }

  before do
    # Login as admin
    visit login_path
    fill_in '이메일 주소', with: admin_user.email
    fill_in '비밀번호', with: 'SecurePass123!'
    click_button '로그인'
  end

  describe 'Dashboard Layout' do
    it 'displays the main navigation' do
      expect(page).to have_content('규정 관리 시스템')
      expect(page).to have_content("안녕하세요, #{admin_user.name}님")
      expect(page).to have_link('로그아웃')
    end

    it 'displays the page title' do
      expect(page).to have_content('관리자 대시보드')
    end

    it 'has proper page structure' do
      expect(page).to have_css('nav')
      expect(page).to have_css('.max-w-7xl')
      expect(page).to have_css('.grid')
    end
  end

  describe 'Statistics Cards' do
    it 'displays all statistics cards' do
      expect(page).to have_content('총 사용자')
      expect(page).to have_content('총 편')
      expect(page).to have_content('총 규정')
      expect(page).to have_content('최근 로그인')
    end

    it 'shows correct user count' do
      within('.grid') do
        expect(page).to have_content('총 사용자')
        # Should show at least 1 (the logged in admin)
        expect(page).to have_content('1')
      end
    end

    it 'shows correct edition count' do
      within('.grid') do
        expect(page).to have_content('총 편')
        expect(page).to have_content('1')
      end
    end

    it 'shows correct regulation count' do
      within('.grid') do
        expect(page).to have_content('총 규정')
        expect(page).to have_content('1')
      end
    end

    it 'displays statistics with proper styling' do
      expect(page).to have_css('.bg-blue-500')
      expect(page).to have_css('.bg-green-500')
      expect(page).to have_css('.bg-yellow-500')
      expect(page).to have_css('.bg-purple-500')
    end
  end

  describe 'Recent Users Section' do
    it 'displays recent users section' do
      expect(page).to have_content('최근 로그인 사용자')
      expect(page).to have_content('최근 로그인한 사용자 목록입니다.')
    end

    it 'shows current user in recent users list' do
      within('.divide-y') do
        expect(page).to have_content(admin_user.name)
        expect(page).to have_content(admin_user.email)
      end
    end

    it 'displays user role badges' do
      expect(page).to have_css('.bg-blue-100.text-blue-800', text: '관리자')
    end

    it 'shows user avatars' do
      expect(page).to have_css('.rounded-full.bg-gray-300')
    end
  end

  describe 'System Information Section' do
    it 'displays system information section' do
      expect(page).to have_content('시스템 정보')
      expect(page).to have_content('현재 시스템의 상태와 정보입니다.')
    end

    it 'shows Rails version' do
      expect(page).to have_content('Rails 버전')
      expect(page).to have_content(Rails.version)
    end

    it 'shows Ruby version' do
      expect(page).to have_content('Ruby 버전')
      expect(page).to have_content(RUBY_VERSION)
    end

    it 'shows environment' do
      expect(page).to have_content('환경')
      expect(page).to have_content('Test')
    end

    it 'displays environment badge with correct styling' do
      expect(page).to have_css('.bg-yellow-100.text-yellow-800')
    end
  end

  describe 'User Role Display' do
    context 'when logged in as admin' do
      it 'displays admin role correctly' do
        expect(page).to have_content('(admin)')
      end
    end

    context 'when logged in as super admin' do
      before do
        click_link '로그아웃'
        visit login_path
        fill_in '이메일 주소', with: super_admin_user.email
        fill_in '비밀번호', with: 'SecurePass123!'
        click_button '로그인'
      end

      it 'displays super admin role correctly' do
        expect(page).to have_content('(super_admin)')
      end

      it 'shows super admin badge in recent users' do
        expect(page).to have_css('.bg-red-100.text-red-800', text: '슈퍼 관리자')
      end
    end
  end

  describe 'Interactive Elements' do
    it 'logout link works with confirmation' do
      expect(page).to have_link('로그아웃')
      
      accept_confirm do
        click_link '로그아웃'
      end
      
      expect(page).to have_current_path(login_path)
    end

    it 'displays confirmation dialog for logout' do
      expect(page).to have_link('로그아웃', href: logout_path)
      expect(page).to have_css('a[data-confirm]')
    end
  end

  describe 'Data Integrity' do
    it 'updates statistics when new data is created' do
      # Create additional data
      create(:user, role: 'admin')
      create(:edition)
      
      # Refresh page
      visit current_path
      
      # Check updated counts
      within('.grid') do
        expect(page).to have_content('2') # users
      end
    end

    it 'handles empty data gracefully' do
      # Clear all data except current user
      Edition.destroy_all
      Chapter.destroy_all
      Regulation.destroy_all
      Article.destroy_all
      Clause.destroy_all
      
      visit current_path
      
      # Should still display dashboard without errors
      expect(page).to have_content('관리자 대시보드')
      expect(page).to have_content('총 편')
      expect(page).to have_content('0')
    end
  end

  describe 'Accessibility' do
    it 'has proper semantic HTML structure' do
      expect(page).to have_css('nav')
      expect(page).to have_css('main, .max-w-7xl')
      expect(page).to have_css('h1, h2, h3')
    end

    it 'has proper heading hierarchy' do
      expect(page).to have_css('h1', text: '규정 관리 시스템')
      expect(page).to have_css('h2', text: '관리자 대시보드')
      expect(page).to have_css('h3', text: '최근 로그인 사용자')
    end

    it 'has descriptive text for sections' do
      expect(page).to have_content('최근 로그인한 사용자 목록입니다.')
      expect(page).to have_content('현재 시스템의 상태와 정보입니다.')
    end
  end
end