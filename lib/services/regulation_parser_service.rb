# frozen_string_literal: true

# 규정 파서 서비스 - 파서와 벤치마크를 통합한 서비스
class RegulationParserService
  attr_reader :parser, :benchmark, :result

  def initialize
    @parser = RegulationParser.new
    @benchmark = ParserBenchmark.new
  end

  # 파일 파싱 실행 (벤치마크 포함)
  def parse_file_with_benchmark(file_path)
    puts "🚀 규정집 파싱 시작: #{file_path}"
    
    # 벤치마크 시작
    @benchmark.start
    
    begin
      # 파싱 실행
      @result = @parser.parse_file(file_path)
      
      # 벤치마크 종료
      @benchmark.finish
      
      # 결과 출력
      print_parsing_summary
      print_benchmark_report
      
      @result
      
    rescue => e
      @benchmark.record_error("Fatal error: #{e.message}")
      @benchmark.finish
      
      puts "❌ 파싱 실패: #{e.message}"
      puts e.backtrace.first(5)
      
      nil
    end
  end

  # 샘플 파일로 테스트
  def test_with_sample
    sample_file = Rails.root.join('spec', 'fixtures', 'sample_regulation.txt')
    
    if File.exist?(sample_file)
      parse_file_with_benchmark(sample_file)
    else
      puts "❌ 샘플 파일을 찾을 수 없습니다: #{sample_file}"
      nil
    end
  end

  # 전체 규정집 파일로 테스트
  def test_with_full_file
    full_file = Rails.root.join('regulations9-340-20250702.txt')
    
    if File.exist?(full_file)
      puts "⚠️ 대용량 파일 파싱을 시작합니다. 시간이 오래 걸릴 수 있습니다."
      parse_file_with_benchmark(full_file)
    else
      puts "❌ 전체 규정집 파일을 찾을 수 없습니다: #{full_file}"
      nil
    end
  end

  private

  def print_parsing_summary
    return unless @result

    puts "\n" + "=" * 60
    puts "📊 파싱 결과 요약"
    puts "=" * 60
    
    # 기본 통계
    stats = @result[:statistics]
    puts "📈 처리 통계:"
    puts "  - 총 라인 수: #{stats[:total_lines].to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"
    puts "  - 편 수: #{stats[:editions]}"
    puts "  - 장 수: #{stats[:chapters]}"
    puts "  - 규정 수: #{stats[:regulations]}"
    puts "  - 조문 수: #{stats[:articles]}"
    puts "  - 항 수: #{stats[:clauses]}"
    puts "  - 스킵된 라인: #{stats[:skipped_lines]}"
    puts "  - 에러 라인: #{stats[:error_lines]}"
    
    # 성공률
    metadata = @result[:metadata]
    puts "\n🎯 정확도:"
    puts "  - 성공률: #{metadata[:success_rate]}%"
    puts "  - 총 에러 수: #{metadata[:total_errors]}"
    
    # 데이터 구조 미리보기
    if @result[:data][:editions].any?
      puts "\n📚 데이터 구조 미리보기:"
      edition = @result[:data][:editions].first
      puts "  첫 번째 편: #{edition[:number]}편 #{edition[:title]}"
      
      if edition[:chapters].any?
        chapter = edition[:chapters].first
        puts "    첫 번째 장: #{chapter[:number]}장 #{chapter[:title]}"
        
        if chapter[:regulations].any?
          regulation = chapter[:regulations].first
          puts "      첫 번째 규정: #{regulation[:code]} #{regulation[:title]}"
        end
      end
    end
    
    # 에러 요약
    if @result[:errors].any?
      puts "\n⚠️ 발견된 에러들 (최근 5개):"
      @result[:errors].last(5).each do |error|
        puts "  - Line #{error[:line_number]}: #{error[:message]}"
      end
    end
  end

  def print_benchmark_report
    return unless @benchmark.metrics

    puts "\n" + "=" * 60
    puts "⚡ 성능 벤치마크 리포트"
    puts "=" * 60
    
    metrics = @benchmark.metrics
    
    # 처리 성능
    puts "🚀 처리 성능:"
    puts "  - 총 처리 시간: #{format_duration(metrics[:total_duration])}"
    puts "  - 처리 속도: #{metrics[:lines_per_second].round(2)} 라인/초"
    puts "  - 라인당 평균 시간: #{(metrics[:average_line_time] * 1000).round(4)} ms"
    
    # 메모리 사용량
    puts "\n💾 메모리 사용량:"
    puts "  - 시작 메모리: #{metrics[:start_memory_mb]} MB"
    puts "  - 최대 메모리: #{metrics[:peak_memory_mb]} MB"
    puts "  - 사용된 메모리: #{metrics[:memory_used_mb]} MB"
    puts "  - 라인당 메모리: #{metrics[:memory_per_line_bytes]} bytes"
    
    # 성능 등급
    puts "\n🏆 성능 등급:"
    puts "  - 속도: #{speed_grade(metrics[:lines_per_second])}"
    puts "  - 메모리: #{memory_grade(metrics[:memory_per_line_bytes])}"
    puts "  - 정확도: #{accuracy_grade(metrics[:success_rate])}"
    puts "  - 종합: #{overall_grade(metrics)}"
  end

  def format_duration(seconds)
    if seconds < 60
      "#{seconds.round(2)}초"
    elsif seconds < 3600
      minutes = (seconds / 60).to_i
      remaining_seconds = (seconds % 60).round(2)
      "#{minutes}분 #{remaining_seconds}초"
    else
      hours = (seconds / 3600).to_i
      remaining_minutes = ((seconds % 3600) / 60).to_i
      remaining_seconds = (seconds % 60).round(2)
      "#{hours}시간 #{remaining_minutes}분 #{remaining_seconds}초"
    end
  end

  def speed_grade(lines_per_sec)
    case lines_per_sec
    when 0..100 then "D (매우 느림)"
    when 100..500 then "C (느림)"
    when 500..1000 then "B (양호)"
    when 1000..2000 then "A (빠름)"
    else "A+ (매우 빠름)"
    end
  end

  def memory_grade(memory_per_line)
    case memory_per_line
    when 0..100 then "A+ (우수)"
    when 100..500 then "A (양호)"
    when 500..1000 then "B (보통)"
    when 1000..2000 then "C (나쁨)"
    else "D (매우 나쁨)"
    end
  end

  def accuracy_grade(success_rate)
    case success_rate
    when 99..100 then "A+ (우수)"
    when 95..99 then "A (양호)"
    when 90..95 then "B (보통)"
    when 80..90 then "C (나쁨)"
    else "D (매우 나쁨)"
    end
  end

  def overall_grade(metrics)
    speed_score = case metrics[:lines_per_second]
                  when 0..100 then 1
                  when 100..500 then 2
                  when 500..1000 then 3
                  when 1000..2000 then 4
                  else 5
                  end

    memory_score = case metrics[:memory_per_line_bytes]
                   when 0..100 then 5
                   when 100..500 then 4
                   when 500..1000 then 3
                   when 1000..2000 then 2
                   else 1
                   end

    accuracy_score = case metrics[:success_rate]
                     when 99..100 then 5
                     when 95..99 then 4
                     when 90..95 then 3
                     when 80..90 then 2
                     else 1
                     end

    average_score = (speed_score + memory_score + accuracy_score) / 3.0

    case average_score
    when 4.5..5.0 then "A+ (탁월)"
    when 3.5..4.5 then "A (우수)"
    when 2.5..3.5 then "B (양호)"
    when 1.5..2.5 then "C (보통)"
    else "D (개선 필요)"
    end
  end
end