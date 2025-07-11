# frozen_string_literal: true

# 파서 성능 벤치마킹 도구
class ParserBenchmark
  attr_reader :metrics

  def initialize
    @start_time = nil
    @end_time = nil
    @start_memory = nil
    @peak_memory = nil
    @processed_lines = 0
    @errors = []
    @checkpoints = []
  end

  # 벤치마크 시작
  def start
    @start_time = Time.now
    @start_memory = current_memory_usage
    @processed_lines = 0
    @errors = []
    @checkpoints = []
    
    log_checkpoint("Benchmark started")
  end

  # 벤치마크 종료
  def finish
    @end_time = Time.now
    @peak_memory = current_memory_usage
    
    log_checkpoint("Benchmark finished")
    calculate_metrics
  end

  # 라인 처리 기록
  def record_line_processed
    @processed_lines += 1
    
    # 1000라인마다 체크포인트 기록
    if @processed_lines % 1000 == 0
      log_checkpoint("Processed #{@processed_lines} lines")
    end
  end

  # 에러 기록
  def record_error(error)
    @errors << {
      error: error,
      timestamp: Time.now,
      line_number: @processed_lines,
      memory_usage: current_memory_usage
    }
  end

  # 체크포인트 기록
  def log_checkpoint(message)
    @checkpoints << {
      message: message,
      timestamp: Time.now,
      memory_usage: current_memory_usage,
      processed_lines: @processed_lines
    }
  end

  # 메트릭 계산
  def calculate_metrics
    duration = @end_time - @start_time
    memory_used = @peak_memory - @start_memory
    
    @metrics = {
      # 시간 관련 메트릭
      total_duration: duration,
      lines_per_second: @processed_lines / duration,
      average_line_time: duration / @processed_lines,
      
      # 메모리 관련 메트릭
      start_memory_mb: bytes_to_mb(@start_memory),
      peak_memory_mb: bytes_to_mb(@peak_memory),
      memory_used_mb: bytes_to_mb(memory_used),
      memory_per_line_bytes: memory_used / @processed_lines,
      
      # 처리 관련 메트릭
      total_lines: @processed_lines,
      total_errors: @errors.size,
      error_rate: (@errors.size.to_f / @processed_lines * 100).round(4),
      success_rate: (100 - (@errors.size.to_f / @processed_lines * 100)).round(4),
      
      # 체크포인트 정보
      checkpoints: @checkpoints,
      errors: @errors
    }
  end

  # 상세 리포트 생성
  def generate_report
    return "Benchmark not completed" unless @metrics

    report = []
    report << "=" * 60
    report << "REGULATION PARSER BENCHMARK REPORT"
    report << "=" * 60
    report << ""
    
    # 기본 정보
    report << "📊 PROCESSING SUMMARY"
    report << "-" * 30
    report << "Total Lines Processed: #{@metrics[:total_lines].to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"
    report << "Total Duration: #{format_duration(@metrics[:total_duration])}"
    report << "Processing Speed: #{@metrics[:lines_per_second].round(2)} lines/sec"
    report << "Average Time per Line: #{(@metrics[:average_line_time] * 1000).round(4)} ms"
    report << ""
    
    # 메모리 사용량
    report << "💾 MEMORY USAGE"
    report << "-" * 30
    report << "Start Memory: #{@metrics[:start_memory_mb]} MB"
    report << "Peak Memory: #{@metrics[:peak_memory_mb]} MB"
    report << "Memory Used: #{@metrics[:memory_used_mb]} MB"
    report << "Memory per Line: #{@metrics[:memory_per_line_bytes]} bytes"
    report << ""
    
    # 에러 통계
    report << "❌ ERROR STATISTICS"
    report << "-" * 30
    report << "Total Errors: #{@metrics[:total_errors]}"
    report << "Error Rate: #{@metrics[:error_rate]}%"
    report << "Success Rate: #{@metrics[:success_rate]}%"
    report << ""
    
    # 성능 등급
    report << "🏆 PERFORMANCE GRADE"
    report << "-" * 30
    report << "Speed Grade: #{speed_grade}"
    report << "Memory Grade: #{memory_grade}"
    report << "Accuracy Grade: #{accuracy_grade}"
    report << "Overall Grade: #{overall_grade}"
    report << ""
    
    # 체크포인트 (최근 5개만)
    if @metrics[:checkpoints].any?
      report << "📍 RECENT CHECKPOINTS"
      report << "-" * 30
      @metrics[:checkpoints].last(5).each do |checkpoint|
        time_offset = (checkpoint[:timestamp] - @start_time).round(2)
        report << "[#{time_offset}s] #{checkpoint[:message]} (#{bytes_to_mb(checkpoint[:memory_usage])} MB)"
      end
      report << ""
    end
    
    # 에러 상세 (최근 5개만)
    if @metrics[:errors].any?
      report << "🚨 RECENT ERRORS"
      report << "-" * 30
      @metrics[:errors].last(5).each do |error_info|
        time_offset = (error_info[:timestamp] - @start_time).round(2)
        report << "[#{time_offset}s] Line #{error_info[:line_number]}: #{error_info[:error]}"
      end
      report << ""
    end
    
    report << "=" * 60
    report.join("\n")
  end

  # JSON 형태로 메트릭 반환
  def to_json
    @metrics&.to_json
  end

  # CSV 형태로 메트릭 반환
  def to_csv
    return "" unless @metrics

    headers = %w[
      total_duration lines_per_second memory_used_mb
      total_lines total_errors error_rate success_rate
    ]
    
    values = headers.map { |key| @metrics[key.to_sym] }
    
    "#{headers.join(',')}\n#{values.join(',')}"
  end

  private

  # 현재 메모리 사용량 (바이트)
  def current_memory_usage
    if RUBY_PLATFORM =~ /darwin/ # macOS
      `ps -o rss= -p #{Process.pid}`.to_i * 1024
    else # Linux
      `ps -o rss= -p #{Process.pid}`.to_i * 1024
    end
  rescue
    0 # 메모리 측정 실패 시 0 반환
  end

  # 바이트를 MB로 변환
  def bytes_to_mb(bytes)
    (bytes / 1024.0 / 1024.0).round(2)
  end

  # 시간 포맷팅
  def format_duration(seconds)
    if seconds < 60
      "#{seconds.round(2)}s"
    elsif seconds < 3600
      minutes = (seconds / 60).to_i
      remaining_seconds = (seconds % 60).round(2)
      "#{minutes}m #{remaining_seconds}s"
    else
      hours = (seconds / 3600).to_i
      remaining_minutes = ((seconds % 3600) / 60).to_i
      remaining_seconds = (seconds % 60).round(2)
      "#{hours}h #{remaining_minutes}m #{remaining_seconds}s"
    end
  end

  # 속도 등급 계산
  def speed_grade
    lines_per_sec = @metrics[:lines_per_second]
    case lines_per_sec
    when 0..100 then "D (Very Slow)"
    when 100..500 then "C (Slow)"
    when 500..1000 then "B (Good)"
    when 1000..2000 then "A (Fast)"
    else "A+ (Very Fast)"
    end
  end

  # 메모리 등급 계산
  def memory_grade
    memory_per_line = @metrics[:memory_per_line_bytes]
    case memory_per_line
    when 0..100 then "A+ (Excellent)"
    when 100..500 then "A (Good)"
    when 500..1000 then "B (Fair)"
    when 1000..2000 then "C (Poor)"
    else "D (Very Poor)"
    end
  end

  # 정확도 등급 계산
  def accuracy_grade
    success_rate = @metrics[:success_rate]
    case success_rate
    when 99..100 then "A+ (Excellent)"
    when 95..99 then "A (Good)"
    when 90..95 then "B (Fair)"
    when 80..90 then "C (Poor)"
    else "D (Very Poor)"
    end
  end

  # 전체 등급 계산
  def overall_grade
    speed_score = case @metrics[:lines_per_second]
                  when 0..100 then 1
                  when 100..500 then 2
                  when 500..1000 then 3
                  when 1000..2000 then 4
                  else 5
                  end

    memory_score = case @metrics[:memory_per_line_bytes]
                   when 0..100 then 5
                   when 100..500 then 4
                   when 500..1000 then 3
                   when 1000..2000 then 2
                   else 1
                   end

    accuracy_score = case @metrics[:success_rate]
                     when 99..100 then 5
                     when 95..99 then 4
                     when 90..95 then 3
                     when 80..90 then 2
                     else 1
                     end

    average_score = (speed_score + memory_score + accuracy_score) / 3.0

    case average_score
    when 4.5..5.0 then "A+ (Outstanding)"
    when 3.5..4.5 then "A (Excellent)"
    when 2.5..3.5 then "B (Good)"
    when 1.5..2.5 then "C (Fair)"
    else "D (Needs Improvement)"
    end
  end
end