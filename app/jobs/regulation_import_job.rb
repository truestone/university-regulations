# frozen_string_literal: true

# 규정 임포트 백그라운드 작업
# Sidekiq을 통해 비동기 처리하며 ActionCable로 실시간 진행률 전송
class RegulationImportJob < ApplicationJob
  queue_as :regulation_import

  # 진행률 업데이트를 위한 콜백
  def perform(file_path, user_id = nil, job_id = nil)
    @job_id = job_id || SecureRandom.uuid
    @user_id = user_id
    @start_time = Time.current
    
    # 초기 상태 브로드캐스트
    broadcast_progress(0, "임포트 작업 시작", :started)
    
    begin
      # 파서 및 임포터 로드
      require Rails.root.join('lib', 'services', 'regulation_parser')
      require Rails.root.join('lib', 'services', 'parser_benchmark')
      require Rails.root.join('lib', 'services', 'regulation_parser_service')
      require Rails.root.join('lib', 'services', 'regulation_importer')
      
      broadcast_progress(10, "서비스 로드 완료", :loading)
      
      # 파일 크기 확인
      file_size = File.size(file_path)
      total_lines = count_file_lines(file_path)
      
      broadcast_progress(20, "파일 분석 완료 (#{total_lines}라인, #{format_file_size(file_size)})", :analyzing)
      
      # 파싱 단계
      broadcast_progress(30, "파싱 시작", :parsing)
      
      parser_service = RegulationParserService.new
      parsed_result = parser_service.parse_file_with_benchmark(file_path)
      
      unless parsed_result
        broadcast_progress(100, "파싱 실패", :failed)
        return { success: false, error: "파싱 실패" }
      end
      
      broadcast_progress(60, "파싱 완료", :parsing_complete)
      
      # 임포트 단계
      broadcast_progress(70, "데이터베이스 임포트 시작", :importing)
      
      importer = RegulationImporter.new
      import_success = importer.import_parsed_data(parsed_result)
      
      if import_success
        # 성공 결과 준비
        result = prepare_success_result(parsed_result, importer)
        broadcast_progress(100, "임포트 완료", :completed, result)
        
        # 결과 파일 저장
        save_import_result(result)
        
        result
      else
        broadcast_progress(100, "임포트 실패", :failed)
        { success: false, error: "임포트 실패", errors: importer.errors }
      end
      
    rescue => e
      Rails.logger.error "RegulationImportJob 실패: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      
      broadcast_progress(100, "작업 실패: #{e.message}", :failed)
      { success: false, error: e.message }
    end
  end

  private

  def broadcast_progress(percentage, message, status, data = nil)
    progress_data = {
      job_id: @job_id,
      percentage: percentage,
      message: message,
      status: status,
      timestamp: Time.current.iso8601,
      elapsed_time: Time.current - @start_time,
      data: data
    }
    
    # ActionCable로 브로드캐스트
    ActionCable.server.broadcast(
      "regulation_import_#{@user_id || 'anonymous'}",
      progress_data
    )
    
    # Redis에 진행률 저장 (웹소켓 연결이 끊어진 경우 복구용)
    Rails.cache.write("import_progress_#{@job_id}", progress_data, expires_in: 1.hour)
    
    Rails.logger.info "Import Progress: #{percentage}% - #{message}"
  end

  def count_file_lines(file_path)
    line_count = 0
    File.open(file_path, 'r:UTF-8') do |file|
      file.each_line { line_count += 1 }
    end
    line_count
  rescue
    0
  end

  def format_file_size(bytes)
    if bytes < 1024
      "#{bytes} bytes"
    elsif bytes < 1024 * 1024
      "#{(bytes / 1024.0).round(1)} KB"
    else
      "#{(bytes / 1024.0 / 1024.0).round(1)} MB"
    end
  end

  def prepare_success_result(parsed_result, importer)
    {
      success: true,
      job_id: @job_id,
      parsing_stats: parsed_result[:statistics],
      import_stats: importer.import_stats,
      total_records: calculate_total_records(importer.import_stats),
      errors: importer.errors,
      completed_at: Time.current,
      duration: Time.current - @start_time
    }
  end

  def calculate_total_records(import_stats)
    import_stats.except(:total_processed, :total_errors).sum do |_, stats|
      stats[:created] + stats[:updated]
    end
  end

  def save_import_result(result)
    result_file = Rails.root.join('tmp', "import_result_#{@job_id}.json")
    File.write(result_file, JSON.pretty_generate(result))
    Rails.logger.info "Import result saved: #{result_file}"
  end
end