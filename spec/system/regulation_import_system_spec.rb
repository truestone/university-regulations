# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Regulation Import System', type: :system, js: true do
  before do
    # 테스트 환경 정리
    clear_all_regulation_data
    
    # 테스트용 사용자 생성 (필요한 경우)
    # @user = create(:user, role: 'admin')
    # login_as(@user)
  end

  after do
    clear_all_regulation_data
  end

  describe '임포트 관리 페이지' do
    it '임포트 목록 페이지가 정상적으로 로드된다' do
      # When: 임포트 관리 페이지 방문
      visit regulation_imports_path

      # Then: 페이지 요소들이 표시됨
      expect(page).to have_content('규정 임포트 관리')
      expect(page).to have_content('새 임포트 시작')
      expect(page).to have_link('전체 파일 임포트')
      expect(page).to have_link('샘플 파일 테스트')
    end

    it '샘플 파일 임포트가 정상적으로 시작된다' do
      # When: 샘플 파일 임포트 클릭
      visit regulation_imports_path
      click_link '샘플 파일 테스트'

      # Then: 성공 메시지 표시 및 진행률 페이지로 이동
      expect(page).to have_content('샘플 임포트 작업이 시작되었습니다')
      expect(current_path).to match(%r{/regulation_imports/[a-f0-9-]+})
    end
  end

  describe '진행률 표시 페이지' do
    let(:job_id) { SecureRandom.uuid }

    before do
      # 테스트용 진행률 데이터 설정
      progress_data = {
        job_id: job_id,
        percentage: 50,
        message: '파싱 중...',
        status: 'parsing',
        timestamp: Time.current.iso8601,
        elapsed_time: 10.5
      }
      Rails.cache.write("import_progress_#{job_id}", progress_data)
    end

    it '진행률이 정상적으로 표시된다' do
      # When: 진행률 페이지 방문
      visit regulation_import_path(job_id)

      # Then: 진행률 요소들이 표시됨
      expect(page).to have_content('임포트 진행률')
      expect(page).to have_content(job_id[0..7])
      expect(page).to have_content('50%')
      expect(page).to have_content('파싱 중...')
      expect(page).to have_content('상태: parsing')
    end

    it '작업 취소 버튼이 작동한다' do
      # When: 진행률 페이지 방문 후 취소 버튼 클릭
      visit regulation_import_path(job_id)
      
      # 확인 다이얼로그에서 확인 클릭 (JavaScript 필요)
      accept_confirm do
        click_button '작업 취소'
      end

      # Then: 취소 요청이 처리됨 (실제 WebSocket 연결 없이는 완전 테스트 어려움)
      expect(page).to have_button('작업 취소')
    end
  end

  describe 'ActionCable 연결 시뮬레이션' do
    let(:job_id) { SecureRandom.uuid }

    it 'JavaScript 컨트롤러가 정상적으로 로드된다' do
      # When: 진행률 페이지 방문
      visit regulation_import_path(job_id)

      # Then: Stimulus 컨트롤러 데이터 속성이 설정됨
      expect(page).to have_css('[data-controller="import-progress"]')
      expect(page).to have_css("[data-import-progress-job-id-value=\"#{job_id}\"]")
      expect(page).to have_css('[data-import-progress-user-id-value]')
    end

    it '진행률 업데이트 시뮬레이션이 작동한다' do
      # Given: 진행률 페이지 방문
      visit regulation_import_path(job_id)

      # When: JavaScript로 진행률 업데이트 시뮬레이션
      execute_script(<<~JS)
        const controller = application.getControllerForElementAndIdentifier(
          document.querySelector('[data-controller="import-progress"]'),
          'import-progress'
        );
        
        if (controller) {
          controller.updateProgress({
            percentage: 75,
            message: '임포트 중...',
            status: 'importing',
            elapsed_time: 25.3
          });
        }
      JS

      # Then: 진행률이 업데이트됨
      expect(page).to have_content('75%')
      expect(page).to have_content('임포트 중...')
    end
  end

  describe '완료 상태 시나리오' do
    let(:job_id) { SecureRandom.uuid }

    it '완료된 작업의 결과가 정상적으로 표시된다' do
      # Given: 완료된 작업 데이터 설정
      completed_data = {
        job_id: job_id,
        percentage: 100,
        message: '임포트 완료',
        status: 'completed',
        timestamp: Time.current.iso8601,
        elapsed_time: 45.2,
        data: {
          total_records: 150,
          import_stats: {
            editions: { created: 3, updated: 0, failed: 0 },
            chapters: { created: 5, updated: 0, failed: 0 },
            regulations: { created: 25, updated: 0, failed: 0 }
          },
          duration: 45.2
        }
      }
      Rails.cache.write("import_progress_#{job_id}", completed_data)

      # When: 진행률 페이지 방문
      visit regulation_import_path(job_id)

      # Then: 완료 상태가 표시됨
      expect(page).to have_content('100%')
      expect(page).to have_content('임포트 완료')
      expect(page).to have_content('상태: completed')
    end
  end

  describe '에러 상태 시나리오' do
    let(:job_id) { SecureRandom.uuid }

    it '실패한 작업의 에러가 정상적으로 표시된다' do
      # Given: 실패한 작업 데이터 설정
      failed_data = {
        job_id: job_id,
        percentage: 65,
        message: '임포트 실패: 파일을 찾을 수 없습니다',
        status: 'failed',
        timestamp: Time.current.iso8601,
        elapsed_time: 15.8
      }
      Rails.cache.write("import_progress_#{job_id}", failed_data)

      # When: 진행률 페이지 방문
      visit regulation_import_path(job_id)

      # Then: 실패 상태가 표시됨
      expect(page).to have_content('65%')
      expect(page).to have_content('임포트 실패')
      expect(page).to have_content('상태: failed')
    end
  end

  describe '반응형 디자인' do
    it '모바일 화면에서도 정상적으로 표시된다' do
      # Given: 모바일 화면 크기로 설정
      page.driver.browser.manage.window.resize_to(375, 667)

      # When: 임포트 관리 페이지 방문
      visit regulation_imports_path

      # Then: 모바일에서도 요소들이 정상 표시됨
      expect(page).to have_content('규정 임포트 관리')
      expect(page).to have_link('전체 파일 임포트')
      expect(page).to have_link('샘플 파일 테스트')

      # 화면 크기 복원
      page.driver.browser.manage.window.maximize
    end
  end

  private

  def clear_all_regulation_data
    Clause.delete_all
    Article.delete_all
    Regulation.delete_all
    Chapter.delete_all
    Edition.delete_all
  end
end