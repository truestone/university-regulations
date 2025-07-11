# frozen_string_literal: true

# 규정 임포트 진행률을 실시간으로 전송하는 ActionCable 채널
class RegulationImportChannel < ApplicationCable::Channel
  def subscribed
    # 사용자별 채널 구독
    user_id = params[:user_id] || 'anonymous'
    stream_from "regulation_import_#{user_id}"
    
    Rails.logger.info "RegulationImportChannel subscribed: user_id=#{user_id}"
    
    # 구독 확인 메시지 전송
    transmit({
      type: 'subscription_confirmed',
      message: '실시간 진행률 구독이 시작되었습니다.',
      timestamp: Time.current.iso8601
    })
  end

  def unsubscribed
    Rails.logger.info "RegulationImportChannel unsubscribed"
  end

  # 클라이언트에서 진행률 상태 요청
  def request_status(data)
    job_id = data['job_id']
    return unless job_id
    
    # Redis에서 저장된 진행률 조회
    progress_data = Rails.cache.read("import_progress_#{job_id}")
    
    if progress_data
      transmit({
        type: 'status_response',
        **progress_data
      })
    else
      transmit({
        type: 'status_response',
        job_id: job_id,
        message: '진행률 정보를 찾을 수 없습니다.',
        status: 'not_found'
      })
    end
  end

  # 클라이언트에서 작업 취소 요청
  def cancel_job(data)
    job_id = data['job_id']
    return unless job_id
    
    # Sidekiq에서 작업 취소 시도
    begin
      # 실행 중인 작업 찾기
      Sidekiq::Queue.new('regulation_import').each do |job|
        if job.args.include?(job_id)
          job.delete
          transmit({
            type: 'job_cancelled',
            job_id: job_id,
            message: '작업이 취소되었습니다.',
            timestamp: Time.current.iso8601
          })
          return
        end
      end
      
      # 실행 중인 작업에서 찾기
      Sidekiq::Workers.new.each do |process_id, thread_id, work|
        if work['payload']['args'].include?(job_id)
          transmit({
            type: 'job_cancel_failed',
            job_id: job_id,
            message: '실행 중인 작업은 취소할 수 없습니다.',
            timestamp: Time.current.iso8601
          })
          return
        end
      end
      
      transmit({
        type: 'job_not_found',
        job_id: job_id,
        message: '취소할 작업을 찾을 수 없습니다.',
        timestamp: Time.current.iso8601
      })
      
    rescue => e
      Rails.logger.error "Job cancellation failed: #{e.message}"
      transmit({
        type: 'job_cancel_error',
        job_id: job_id,
        message: '작업 취소 중 오류가 발생했습니다.',
        error: e.message,
        timestamp: Time.current.iso8601
      })
    end
  end

  # 클라이언트에서 작업 목록 요청
  def list_jobs(data)
    begin
      jobs = []
      
      # 대기 중인 작업들
      Sidekiq::Queue.new('regulation_import').each do |job|
        jobs << {
          job_id: job.args.last,
          status: 'queued',
          created_at: Time.at(job.created_at).iso8601,
          queue: job.queue
        }
      end
      
      # 실행 중인 작업들
      Sidekiq::Workers.new.each do |process_id, thread_id, work|
        if work['queue'] == 'regulation_import'
          jobs << {
            job_id: work['payload']['args'].last,
            status: 'running',
            started_at: Time.at(work['run_at']).iso8601,
            queue: work['queue']
          }
        end
      end
      
      transmit({
        type: 'jobs_list',
        jobs: jobs,
        timestamp: Time.current.iso8601
      })
      
    rescue => e
      Rails.logger.error "Jobs list failed: #{e.message}"
      transmit({
        type: 'jobs_list_error',
        message: '작업 목록 조회 중 오류가 발생했습니다.',
        error: e.message,
        timestamp: Time.current.iso8601
      })
    end
  end
end