# frozen_string_literal: true

namespace :regulation do
  desc "Retry failed regulation imports"
  task :retry, [:error_log_file] => :environment do |task, args|
    error_log_file = args[:error_log_file] || find_latest_error_log
    
    unless error_log_file && File.exist?(error_log_file)
      puts "❌ 에러 로그 파일을 찾을 수 없습니다: #{error_log_file}"
      puts "사용법: rails regulation:retry[/path/to/error_log.csv]"
      exit 1
    end
    
    puts "🔄 실패한 임포트 재시도 시작"
    puts "에러 로그: #{error_log_file}"
    puts "=" * 60
    
    # 재시도 핸들러 로드
    require Rails.root.join('lib', 'services', 'regulation_retry_handler')
    
    # 에러 로그에서 실패 데이터 로드
    failed_data = load_failed_data_from_csv(error_log_file)
    
    if failed_data.empty?
      puts "✅ 재시도할 실패 데이터가 없습니다."
      exit 0
    end
    
    puts "📊 재시도 대상: #{failed_data.size}건"
    
    # 재시도 실행
    retry_handler = RegulationRetryHandler.new
    retry_handler.retry_failed_imports(failed_data)
    
    puts "\n🎉 재시도 작업 완료!"
  end

  desc "Analyze failure patterns from error log"
  task :analyze_failures, [:error_log_file] => :environment do |task, args|
    error_log_file = args[:error_log_file] || find_latest_error_log
    
    unless error_log_file && File.exist?(error_log_file)
      puts "❌ 에러 로그 파일을 찾을 수 없습니다: #{error_log_file}"
      exit 1
    end
    
    puts "📊 실패 패턴 분석 시작"
    puts "에러 로그: #{error_log_file}"
    puts "=" * 60
    
    # 재시도 핸들러 로드
    require Rails.root.join('lib', 'services', 'regulation_retry_handler')
    
    # 실패 패턴 분석
    retry_handler = RegulationRetryHandler.new
    retry_handler.analyze_failure_patterns(error_log_file)
    
    puts "\n✅ 실패 패턴 분석 완료!"
  end

  desc "Schedule automatic retry for failed imports"
  task :schedule_retry, [:error_log_file, :delay_minutes] => :environment do |task, args|
    error_log_file = args[:error_log_file] || find_latest_error_log
    delay_minutes = (args[:delay_minutes] || 30).to_i
    
    unless error_log_file && File.exist?(error_log_file)
      puts "❌ 에러 로그 파일을 찾을 수 없습니다: #{error_log_file}"
      exit 1
    end
    
    puts "⏰ 자동 재시도 스케줄링"
    puts "에러 로그: #{error_log_file}"
    puts "지연 시간: #{delay_minutes}분"
    puts "=" * 60
    
    # 재시도 핸들러 로드
    require Rails.root.join('lib', 'services', 'regulation_retry_handler')
    
    # 자동 재시도 스케줄링
    retry_handler = RegulationRetryHandler.new
    retry_handler.schedule_auto_retry(error_log_file, delay_minutes: delay_minutes)
    
    puts "\n✅ 자동 재시도 스케줄링 완료!"
  end

  desc "Clean up old retry logs and reports"
  task :cleanup_logs, [:days_old] => :environment do |task, args|
    days_old = (args[:days_old] || 7).to_i
    cutoff_date = Date.current - days_old.days
    
    puts "🗑️ 오래된 재시도 로그 정리"
    puts "기준 날짜: #{cutoff_date} (#{days_old}일 이전)"
    puts "=" * 60
    
    tmp_dir = Rails.root.join('tmp')
    cleaned_files = 0
    
    # 에러 로그 파일 정리
    Dir.glob(tmp_dir.join('import_errors_*.csv')).each do |file|
      file_date = extract_date_from_filename(file)
      if file_date && file_date < cutoff_date
        File.delete(file)
        cleaned_files += 1
        puts "🗑️ 삭제: #{File.basename(file)}"
      end
    end
    
    # 재시도 리포트 파일 정리
    Dir.glob(tmp_dir.join('retry_report_*.json')).each do |file|
      file_date = extract_date_from_filename(file)
      if file_date && file_date < cutoff_date
        File.delete(file)
        cleaned_files += 1
        puts "🗑️ 삭제: #{File.basename(file)}"
      end
    end
    
    # 임포트 결과 파일 정리
    Dir.glob(tmp_dir.join('import_result*.json')).each do |file|
      file_date = extract_date_from_filename(file)
      if file_date && file_date < cutoff_date
        File.delete(file)
        cleaned_files += 1
        puts "🗑️ 삭제: #{File.basename(file)}"
      end
    end
    
    puts "\n✅ 정리 완료: #{cleaned_files}개 파일 삭제"
  end

  desc "Show retry help"
  task :retry_help do
    puts "🔄 규정 재시도 사용법"
    puts "=" * 60
    puts ""
    puts "사용 가능한 작업:"
    puts ""
    puts "1. 실패한 임포트 재시도:"
    puts "   rails regulation:retry"
    puts "   rails regulation:retry[/path/to/error_log.csv]"
    puts ""
    puts "2. 실패 패턴 분석:"
    puts "   rails regulation:analyze_failures"
    puts "   rails regulation:analyze_failures[/path/to/error_log.csv]"
    puts ""
    puts "3. 자동 재시도 스케줄링:"
    puts "   rails regulation:schedule_retry"
    puts "   rails regulation:schedule_retry[/path/to/error_log.csv,60]"
    puts ""
    puts "4. 오래된 로그 정리:"
    puts "   rails regulation:cleanup_logs"
    puts "   rails regulation:cleanup_logs[14]  # 14일 이전 파일 삭제"
    puts ""
    puts "5. 재시도 도움말:"
    puts "   rails regulation:retry_help"
    puts ""
    puts "📁 로그 파일은 tmp/ 디렉토리에서 자동으로 찾습니다."
    puts ""
  end

  private

  def find_latest_error_log
    tmp_dir = Rails.root.join('tmp')
    error_logs = Dir.glob(tmp_dir.join('import_errors_*.csv')).sort_by { |f| File.mtime(f) }
    error_logs.last
  end

  def load_failed_data_from_csv(csv_file)
    require 'csv'
    failed_data = []
    
    CSV.foreach(csv_file, headers: true) do |row|
      begin
        data = JSON.parse(row['Data'])
        failed_data << {
          type: row['Type'].to_sym,
          timestamp: row['Timestamp'],
          errors: row['Errors'].split('; '),
          data: data
        }
      rescue JSON::ParserError => e
        puts "⚠️ JSON 파싱 실패: #{row['Data']} - #{e.message}"
      end
    end
    
    failed_data
  end

  def extract_date_from_filename(filename)
    # 파일명에서 날짜 추출: import_errors_20250111_123456.csv
    match = File.basename(filename).match(/(\d{8})_\d{6}/)
    return nil unless match
    
    date_str = match[1]
    Date.parse("#{date_str[0..3]}-#{date_str[4..5]}-#{date_str[6..7]}")
  rescue Date::Error
    nil
  end
end