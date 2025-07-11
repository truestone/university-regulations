# frozen_string_literal: true

namespace :regulation do
  desc "Parse regulation file and show statistics"
  task :parse, [:file_path] => :environment do |task, args|
    file_path = args[:file_path] || Rails.root.join('regulations9-340-20250702.txt')
    
    puts "🚀 규정집 파싱 작업 시작"
    puts "파일: #{file_path}"
    puts "=" * 60
    
    # 파서 서비스 로드
    require Rails.root.join('lib', 'services', 'regulation_parser')
    require Rails.root.join('lib', 'services', 'parser_benchmark')
    require Rails.root.join('lib', 'services', 'regulation_parser_service')
    
    # 파싱 실행
    service = RegulationParserService.new
    result = service.parse_file_with_benchmark(file_path)
    
    if result
      puts "\n🎉 파싱 작업 완료!"
      
      # 결과를 JSON 파일로 저장
      output_file = Rails.root.join('tmp', 'parsed_regulations.json')
      File.write(output_file, JSON.pretty_generate(result))
      puts "📄 결과 저장: #{output_file}"
      
    else
      puts "\n❌ 파싱 작업 실패"
      exit 1
    end
  end

  desc "Parse sample regulation file for testing"
  task :parse_sample => :environment do
    puts "🧪 샘플 파일 파싱 테스트"
    puts "=" * 60
    
    # 파서 서비스 로드
    require Rails.root.join('lib', 'services', 'regulation_parser')
    require Rails.root.join('lib', 'services', 'parser_benchmark')
    require Rails.root.join('lib', 'services', 'regulation_parser_service')
    
    # 샘플 파싱 실행
    service = RegulationParserService.new
    result = service.test_with_sample
    
    if result
      puts "\n🎉 샘플 파싱 테스트 완료!"
    else
      puts "\n❌ 샘플 파싱 테스트 실패"
      exit 1
    end
  end

  desc "Parse first N lines of regulation file for testing"
  task :parse_partial, [:lines] => :environment do |task, args|
    lines = (args[:lines] || 1000).to_i
    full_file = Rails.root.join('regulations9-340-20250702.txt')
    test_file = Rails.root.join('tmp', "test_regulations_#{lines}.txt")
    
    puts "🧪 부분 파일 파싱 테스트 (#{lines}라인)"
    puts "=" * 60
    
    unless File.exist?(full_file)
      puts "❌ 전체 규정집 파일을 찾을 수 없습니다: #{full_file}"
      exit 1
    end
    
    # 부분 파일 생성
    puts "📝 테스트 파일 생성 중..."
    File.open(test_file, 'w:UTF-8') do |output|
      File.open(full_file, 'r:UTF-8').each_line.with_index do |line, index|
        output.write(line)
        break if index >= lines - 1
      end
    end
    
    puts "✅ 테스트 파일 생성 완료: #{test_file}"
    
    # 파서 서비스 로드
    require Rails.root.join('lib', 'services', 'regulation_parser')
    require Rails.root.join('lib', 'services', 'parser_benchmark')
    require Rails.root.join('lib', 'services', 'regulation_parser_service')
    
    # 파싱 실행
    service = RegulationParserService.new
    result = service.parse_file_with_benchmark(test_file)
    
    if result
      puts "\n🎉 부분 파싱 테스트 완료!"
      
      # 결과를 JSON 파일로 저장
      output_file = Rails.root.join('tmp', "parsed_regulations_#{lines}.json")
      File.write(output_file, JSON.pretty_generate(result))
      puts "📄 결과 저장: #{output_file}"
      
    else
      puts "\n❌ 부분 파싱 테스트 실패"
    end
    
    # 임시 파일 정리
    File.delete(test_file) if File.exist?(test_file)
    puts "🗑️ 임시 파일 정리 완료"
  end

  desc "Show regulation parser help"
  task :help do
    puts "📚 규정집 파서 사용법"
    puts "=" * 60
    puts ""
    puts "사용 가능한 작업:"
    puts ""
    puts "1. 샘플 파일 파싱 테스트:"
    puts "   rails regulation:parse_sample"
    puts ""
    puts "2. 부분 파일 파싱 테스트 (기본 1000라인):"
    puts "   rails regulation:parse_partial"
    puts "   rails regulation:parse_partial[5000]"
    puts ""
    puts "3. 전체 파일 파싱:"
    puts "   rails regulation:parse"
    puts "   rails regulation:parse[/path/to/file.txt]"
    puts ""
    puts "4. 도움말:"
    puts "   rails regulation:help"
    puts ""
    puts "📁 결과 파일은 tmp/ 디렉토리에 저장됩니다."
    puts ""
  end
end