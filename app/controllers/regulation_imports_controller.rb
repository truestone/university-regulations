# frozen_string_literal: true

# 규정 임포트 컨트롤러
# 백그라운드 임포트 작업 시작 및 진행률 모니터링
class RegulationImportsController < ApplicationController
  before_action :authenticate_admin

  def index
    @import_jobs = get_current_import_jobs
    @recent_results = get_recent_import_results
  end

  def new
    # 임포트 폼 페이지
  end

  def create
    file_path = params[:file_path] || Rails.root.join('regulations9-340-20250702.txt')
    
    unless File.exist?(file_path)
      flash[:error] = "파일을 찾을 수 없습니다: #{file_path}"
      redirect_to regulation_imports_path
      return
    end
    
    # 백그라운드 작업 시작
    job_id = SecureRandom.uuid
    user_id = current_user&.id || 'anonymous'
    
    RegulationImportJob.perform_later(file_path, user_id, job_id)
    
    flash[:success] = "임포트 작업이 시작되었습니다. (Job ID: #{job_id})"
    redirect_to regulation_import_path(job_id)
  end

  def show
    @job_id = params[:id]
    @user_id = current_user&.id || 'anonymous'
    
    # Redis에서 저장된 진행률 조회
    @progress_data = Rails.cache.read("import_progress_#{@job_id}")
    
    unless @progress_data
      flash[:warning] = "진행률 정보를 찾을 수 없습니다."
    end
  end

  def status
    job_id = params[:id]
    progress_data = Rails.cache.read("import_progress_#{job_id}")
    
    if progress_data
      render json: progress_data
    else
      render json: { error: "진행률 정보를 찾을 수 없습니다." }, status: 404
    end
  end

  def cancel
    job_id = params[:id]
    
    begin
      # Sidekiq에서 작업 취소
      cancelled = cancel_sidekiq_job(job_id)
      
      if cancelled
        render json: { success: true, message: "작업이 취소되었습니다." }
      else
        render json: { success: false, message: "취소할 작업을 찾을 수 없습니다." }
      end
      
    rescue => e
      Rails.logger.error "Job cancellation failed: #{e.message}"
      render json: { success: false, message: "작업 취소 중 오류가 발생했습니다." }, status: 500
    end
  end

  def sample
    # 샘플 파일로 임포트 테스트
    sample_file = Rails.root.join('spec', 'fixtures', 'sample_regulation.txt')
    
    unless File.exist?(sample_file)
      flash[:error] = "샘플 파일을 찾을 수 없습니다."
      redirect_to regulation_imports_path
      return
    end
    
    job_id = SecureRandom.uuid
    user_id = current_user&.id || 'anonymous'
    
    RegulationImportJob.perform_later(sample_file.to_s, user_id, job_id)
    
    flash[:success] = "샘플 임포트 작업이 시작되었습니다. (Job ID: #{job_id})"
    redirect_to regulation_import_path(job_id)
  end

  private

  def authenticate_admin
    # 실제 구현에서는 적절한 인증 로직 사용
    # redirect_to root_path unless current_user&.admin?
  end

  def get_current_import_jobs
    jobs = []
    
    begin
      # 대기 중인 작업들
      Sidekiq::Queue.new('regulation_import').each do |job|
        jobs << {
          job_id: job.args.last,
          status: 'queued',
          created_at: Time.at(job.created_at),
          file_path: job.args.first
        }
      end
      
      # 실행 중인 작업들
      Sidekiq::Workers.new.each do |process_id, thread_id, work|
        if work['queue'] == 'regulation_import'
          jobs << {
            job_id: work['payload']['args'].last,
            status: 'running',
            started_at: Time.at(work['run_at']),
            file_path: work['payload']['args'].first
          }
        end
      end
      
    rescue => e
      Rails.logger.error "Failed to get import jobs: #{e.message}"
    end
    
    jobs
  end

  def get_recent_import_results
    results = []
    
    begin
      # tmp 디렉토리에서 최근 결과 파일들 조회
      result_files = Dir.glob(Rails.root.join('tmp', 'import_result_*.json'))
                        .sort_by { |f| File.mtime(f) }
                        .reverse
                        .first(10)
      
      result_files.each do |file|
        begin
          data = JSON.parse(File.read(file))
          results << {
            job_id: data['job_id'],
            success: data['success'],
            completed_at: data['completed_at'],
            duration: data['duration'],
            total_records: data['total_records'],
            errors_count: data['errors']&.size || 0
          }
        rescue JSON::ParserError => e
          Rails.logger.error "Failed to parse result file #{file}: #{e.message}"
        end
      end
      
    rescue => e
      Rails.logger.error "Failed to get recent results: #{e.message}"
    end
    
    results
  end

  def cancel_sidekiq_job(job_id)
    # 대기 중인 작업에서 찾기
    Sidekiq::Queue.new('regulation_import').each do |job|
      if job.args.include?(job_id)
        job.delete
        return true
      end
    end
    
    # 실행 중인 작업은 취소할 수 없음
    false
  end
end