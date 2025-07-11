# frozen_string_literal: true

# 규정 임포트 실패 로깅 및 재시도 처리 서비스
class RegulationRetryHandler
  attr_reader :retry_stats, :failed_records, :retry_attempts

  MAX_RETRY_ATTEMPTS = 3
  RETRY_DELAY_BASE = 2 # seconds
  
  def initialize
    @retry_stats = {
      total_retries: 0,
      successful_retries: 0,
      failed_retries: 0,
      permanent_failures: 0
    }
    @failed_records = []
    @retry_attempts = {}
  end

  # 실패한 레코드 재시도 처리
  def retry_failed_imports(failed_data)
    puts "🔄 실패한 임포트 재시도 시작"
    puts "=" * 60
    
    failed_data.each_with_index do |failed_item, index|
      retry_single_record(failed_item, index + 1, failed_data.size)
    end
    
    print_retry_summary
    generate_retry_report
  end

  # 단일 레코드 재시도
  def retry_single_record(failed_item, current_index, total_count)
    record_id = generate_record_id(failed_item)
    attempt_count = @retry_attempts[record_id] || 0
    
    puts "\n🔄 재시도 #{current_index}/#{total_count}: #{failed_item[:type]} (시도 #{attempt_count + 1}/#{MAX_RETRY_ATTEMPTS})"
    
    if attempt_count >= MAX_RETRY_ATTEMPTS
      handle_permanent_failure(failed_item, record_id)
      return false
    end
    
    # 지수 백오프 지연
    delay = calculate_retry_delay(attempt_count)
    sleep(delay) if attempt_count > 0
    
    @retry_attempts[record_id] = attempt_count + 1
    @retry_stats[:total_retries] += 1
    
    begin
      success = execute_retry_logic(failed_item)
      
      if success
        handle_retry_success(failed_item, record_id)
        true
      else
        handle_retry_failure(failed_item, record_id)
        false
      end
      
    rescue => e
      handle_retry_exception(failed_item, record_id, e)
      false
    end
  end

  # 재시도 로직 실행
  def execute_retry_logic(failed_item)
    case failed_item[:type]
    when :edition
      retry_edition_import(failed_item)
    when :chapter
      retry_chapter_import(failed_item)
    when :regulation
      retry_regulation_import(failed_item)
    when :article
      retry_article_import(failed_item)
    when :clause
      retry_clause_import(failed_item)
    else
      puts "  ❌ 알 수 없는 타입: #{failed_item[:type]}"
      false
    end
  end

  # 실패한 임포트 로그 분석
  def analyze_failure_patterns(error_log_file)
    puts "📊 실패 패턴 분석 시작: #{error_log_file}"
    
    unless File.exist?(error_log_file)
      puts "❌ 에러 로그 파일을 찾을 수 없습니다: #{error_log_file}"
      return
    end
    
    require 'csv'
    
    failure_patterns = {
      validation_errors: [],
      constraint_violations: [],
      data_format_errors: [],
      unknown_errors: []
    }
    
    CSV.foreach(error_log_file, headers: true) do |row|
      error_type = categorize_error(row['Errors'])
      failure_patterns[error_type] << {
        type: row['Type'],
        timestamp: row['Timestamp'],
        errors: row['Errors'],
        data: (JSON.parse(row['Data']) rescue {})
      }
    end
    
    print_failure_analysis(failure_patterns)
    generate_retry_recommendations(failure_patterns)
  end

  # 자동 재시도 스케줄링
  def schedule_auto_retry(error_log_file, delay_minutes: 30)
    puts "⏰ 자동 재시도 스케줄링: #{delay_minutes}분 후"
    
    # Sidekiq job으로 스케줄링 (실제 구현에서는 Sidekiq 사용)
    retry_job_data = {
      error_log_file: error_log_file,
      scheduled_at: Time.current + delay_minutes.minutes,
      retry_count: 1
    }
    
    # 임시로 파일에 저장 (실제로는 Sidekiq.perform_in 사용)
    schedule_file = Rails.root.join('tmp', 'retry_schedule.json')
    schedules = File.exist?(schedule_file) ? JSON.parse(File.read(schedule_file)) : []
    schedules << retry_job_data
    
    File.write(schedule_file, JSON.pretty_generate(schedules))
    puts "✅ 재시도 작업 스케줄링 완료: #{schedule_file}"
  end

  private

  def retry_edition_import(failed_item)
    data = failed_item[:data]
    
    # 데이터 정제 시도
    cleaned_data = clean_edition_data(data)
    
    edition = Edition.find_or_initialize_by(number: cleaned_data[:number])
    edition.assign_attributes(
      title: cleaned_data[:title],
      description: cleaned_data[:description],
      sort_order: cleaned_data[:number],
      is_active: true
    )
    
    if edition.save
      puts "  ✅ 편 #{cleaned_data[:number]} 재시도 성공"
      true
    else
      puts "  ❌ 편 재시도 실패: #{edition.errors.full_messages.join(', ')}"
      false
    end
  end

  def retry_chapter_import(failed_item)
    data = failed_item[:data]
    
    # 부모 편 확인
    edition = Edition.find_by(number: data[:edition_number])
    unless edition
      puts "  ❌ 부모 편을 찾을 수 없음: #{data[:edition_number]}"
      return false
    end
    
    cleaned_data = clean_chapter_data(data)
    
    chapter = Chapter.find_or_initialize_by(
      edition: edition,
      number: cleaned_data[:number]
    )
    chapter.assign_attributes(
      title: cleaned_data[:title],
      description: cleaned_data[:description],
      sort_order: cleaned_data[:number],
      is_active: true
    )
    
    if chapter.save
      puts "  ✅ 장 #{cleaned_data[:number]} 재시도 성공"
      true
    else
      puts "  ❌ 장 재시도 실패: #{chapter.errors.full_messages.join(', ')}"
      false
    end
  end

  def retry_regulation_import(failed_item)
    data = failed_item[:data]
    
    # 규정 코드 정제
    cleaned_code = clean_regulation_code(data[:code])
    return false unless cleaned_code
    
    # 부모 장 찾기
    chapter = find_chapter_for_regulation(cleaned_code)
    unless chapter
      puts "  ❌ 적절한 장을 찾을 수 없음: #{cleaned_code}"
      return false
    end
    
    regulation = Regulation.find_or_initialize_by(regulation_code: cleaned_code)
    regulation.assign_attributes(
      chapter: chapter,
      title: data[:title],
      content: data[:content],
      number: extract_regulation_number(cleaned_code),
      status: 'active',
      sort_order: extract_regulation_number(cleaned_code),
      is_active: true
    )
    
    if regulation.save
      puts "  ✅ 규정 #{cleaned_code} 재시도 성공"
      true
    else
      puts "  ❌ 규정 재시도 실패: #{regulation.errors.full_messages.join(', ')}"
      false
    end
  end

  def retry_article_import(failed_item)
    data = failed_item[:data]
    
    # 부모 규정 찾기
    regulation = Regulation.find_by(regulation_code: data[:regulation_code])
    unless regulation
      puts "  ❌ 부모 규정을 찾을 수 없음: #{data[:regulation_code]}"
      return false
    end
    
    article = Article.find_or_initialize_by(
      regulation: regulation,
      number: data[:number]
    )
    article.assign_attributes(
      title: data[:title],
      content: data[:content],
      sort_order: data[:number],
      is_active: true
    )
    
    if article.save
      puts "  ✅ 조문 #{data[:number]} 재시도 성공"
      true
    else
      puts "  ❌ 조문 재시도 실패: #{article.errors.full_messages.join(', ')}"
      false
    end
  end

  def retry_clause_import(failed_item)
    data = failed_item[:data]
    
    # 부모 조문 찾기
    article = Article.joins(:regulation)
                    .find_by(number: data[:article_number], 
                            regulations: { regulation_code: data[:regulation_code] })
    unless article
      puts "  ❌ 부모 조문을 찾을 수 없음: #{data[:article_number]}"
      return false
    end
    
    clause = Clause.find_or_initialize_by(
      article: article,
      number: data[:number]
    )
    clause.assign_attributes(
      content: data[:content],
      clause_type: data[:type] || 'paragraph',
      sort_order: data[:number],
      is_active: true
    )
    
    if clause.save
      puts "  ✅ 항 #{data[:number]} 재시도 성공"
      true
    else
      puts "  ❌ 항 재시도 실패: #{clause.errors.full_messages.join(', ')}"
      false
    end
  end

  def clean_edition_data(data)
    {
      number: data[:number].to_i,
      title: data[:title]&.strip,
      description: data[:description]&.strip
    }
  end

  def clean_chapter_data(data)
    {
      number: data[:number].to_i,
      title: data[:title]&.strip,
      description: data[:description]&.strip,
      edition_number: data[:edition_number]
    }
  end

  def clean_regulation_code(code)
    # 규정 코드 정제: "3-1-1" 형식으로 변환
    return nil unless code
    
    cleaned = code.strip.gsub(/[^\d-]/, '')
    parts = cleaned.split('-')
    
    if parts.size == 3 && parts.all? { |p| p.match?(/^\d+$/) }
      parts.join('-')
    else
      # 기본 형식으로 변환 시도
      "1-1-#{rand(1000..9999)}"
    end
  end

  def find_chapter_for_regulation(regulation_code)
    # 규정 코드에서 편-장 정보 추출
    parts = regulation_code.split('-')
    edition_num = parts[0].to_i
    chapter_num = parts[1].to_i
    
    edition = Edition.find_by(number: edition_num)
    return nil unless edition
    
    chapter = Chapter.find_by(edition: edition, number: chapter_num)
    
    # 장이 없으면 기본 장 생성
    unless chapter
      chapter = Chapter.create!(
        edition: edition,
        number: chapter_num,
        title: "기타",
        sort_order: chapter_num,
        is_active: true
      )
    end
    
    chapter
  end

  def extract_regulation_number(regulation_code)
    parts = regulation_code.split('-')
    parts.last.to_i
  end

  def generate_record_id(failed_item)
    "#{failed_item[:type]}_#{failed_item[:data].hash}"
  end

  def calculate_retry_delay(attempt_count)
    RETRY_DELAY_BASE ** attempt_count
  end

  def handle_retry_success(failed_item, record_id)
    @retry_stats[:successful_retries] += 1
    @retry_attempts.delete(record_id)
    puts "  ✅ 재시도 성공"
  end

  def handle_retry_failure(failed_item, record_id)
    @retry_stats[:failed_retries] += 1
    puts "  ❌ 재시도 실패"
  end

  def handle_retry_exception(failed_item, record_id, exception)
    @retry_stats[:failed_retries] += 1
    puts "  ❌ 재시도 중 예외 발생: #{exception.message}"
  end

  def handle_permanent_failure(failed_item, record_id)
    @retry_stats[:permanent_failures] += 1
    @failed_records << {
      record_id: record_id,
      type: failed_item[:type],
      data: failed_item[:data],
      final_errors: failed_item[:errors],
      attempts: MAX_RETRY_ATTEMPTS,
      marked_as_permanent: Time.current
    }
    puts "  ❌ 영구 실패로 처리 (최대 재시도 횟수 초과)"
  end

  def categorize_error(error_message)
    case error_message.downcase
    when /validation/
      :validation_errors
    when /constraint|unique|duplicate/
      :constraint_violations
    when /format|invalid|parse/
      :data_format_errors
    else
      :unknown_errors
    end
  end

  def print_retry_summary
    puts "\n" + "=" * 60
    puts "🔄 재시도 결과 요약"
    puts "=" * 60
    
    puts "📊 재시도 통계:"
    puts "  - 총 재시도: #{@retry_stats[:total_retries]}"
    puts "  - 성공한 재시도: #{@retry_stats[:successful_retries]}"
    puts "  - 실패한 재시도: #{@retry_stats[:failed_retries]}"
    puts "  - 영구 실패: #{@retry_stats[:permanent_failures]}"
    
    success_rate = if @retry_stats[:total_retries] > 0
                     (@retry_stats[:successful_retries].to_f / @retry_stats[:total_retries] * 100).round(2)
                   else
                     0.0
                   end
    puts "  - 재시도 성공률: #{success_rate}%"
  end

  def print_failure_analysis(failure_patterns)
    puts "\n" + "=" * 60
    puts "📊 실패 패턴 분석"
    puts "=" * 60
    
    failure_patterns.each do |pattern, errors|
      next if errors.empty?
      
      puts "\n#{pattern.to_s.humanize}: #{errors.size}건"
      errors.first(3).each do |error|
        puts "  - #{error[:type]}: #{error[:errors]}"
      end
      puts "  ..." if errors.size > 3
    end
  end

  def generate_retry_recommendations(failure_patterns)
    puts "\n" + "=" * 60
    puts "💡 재시도 권장사항"
    puts "=" * 60
    
    if failure_patterns[:validation_errors].any?
      puts "🔧 Validation 에러:"
      puts "  - 데이터 정제 로직 강화 필요"
      puts "  - 필수 필드 누락 확인"
    end
    
    if failure_patterns[:constraint_violations].any?
      puts "🔧 제약 조건 위반:"
      puts "  - 중복 데이터 처리 로직 개선"
      puts "  - unique 제약 조건 확인"
    end
    
    if failure_patterns[:data_format_errors].any?
      puts "🔧 데이터 형식 에러:"
      puts "  - 파싱 로직 개선 필요"
      puts "  - 데이터 형식 표준화"
    end
  end

  def generate_retry_report
    report_file = Rails.root.join('tmp', "retry_report_#{Time.current.strftime('%Y%m%d_%H%M%S')}.json")
    
    report_data = {
      retry_stats: @retry_stats,
      failed_records: @failed_records,
      retry_attempts: @retry_attempts,
      generated_at: Time.current
    }
    
    File.write(report_file, JSON.pretty_generate(report_data))
    puts "\n📄 재시도 리포트 저장: #{report_file}"
  end
end