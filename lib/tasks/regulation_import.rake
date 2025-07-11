# frozen_string_literal: true

namespace :regulation do
  desc "Import regulation data from parsed file"
  task :import, [:file_path] => :environment do |task, args|
    file_path = args[:file_path] || Rails.root.join('regulations9-340-20250702.txt')
    
    puts "🚀 규정 데이터 임포트 작업 시작"
    puts "파일: #{file_path}"
    puts "=" * 60
    
    # 임포터 서비스 로드
    require Rails.root.join('lib', 'services', 'regulation_parser')
    require Rails.root.join('lib', 'services', 'parser_benchmark')
    require Rails.root.join('lib', 'services', 'regulation_parser_service')
    require Rails.root.join('lib', 'services', 'regulation_importer')
    
    # 임포트 실행
    importer = RegulationImporter.new
    success = importer.import_from_file(file_path)
    
    if success
      puts "\n🎉 임포트 작업 완료!"
      
      # 결과를 JSON 파일로 저장
      output_file = Rails.root.join('tmp', 'import_result.json')
      File.write(output_file, importer.to_json)
      puts "📄 결과 저장: #{output_file}"
      
      # 에러가 있으면 CSV로 저장
      if importer.errors.any?
        error_file = importer.save_error_log
        puts "📄 에러 로그 저장: #{error_file}"
      end
      
    else
      puts "\n❌ 임포트 작업 실패"
      
      # 에러 로그 저장
      error_file = importer.save_error_log
      puts "📄 에러 로그 저장: #{error_file}"
      
      exit 1
    end
  end

  desc "Import sample regulation data for testing"
  task :import_sample => :environment do
    puts "🧪 샘플 데이터 임포트 테스트"
    puts "=" * 60
    
    # 임포터 서비스 로드
    require Rails.root.join('lib', 'services', 'regulation_parser')
    require Rails.root.join('lib', 'services', 'parser_benchmark')
    require Rails.root.join('lib', 'services', 'regulation_parser_service')
    require Rails.root.join('lib', 'services', 'regulation_importer')
    
    # 샘플 파일 경로
    sample_file = Rails.root.join('spec', 'fixtures', 'sample_regulation.txt')
    
    unless File.exist?(sample_file)
      puts "❌ 샘플 파일을 찾을 수 없습니다: #{sample_file}"
      exit 1
    end
    
    # 임포트 실행
    importer = RegulationImporter.new
    success = importer.import_from_file(sample_file)
    
    if success
      puts "\n🎉 샘플 임포트 테스트 완료!"
      
      # 데이터베이스 확인
      puts "\n📊 데이터베이스 현황:"
      puts "  - 편 수: #{Edition.count}"
      puts "  - 장 수: #{Chapter.count}"
      puts "  - 규정 수: #{Regulation.count}"
      puts "  - 조문 수: #{Article.count}"
      puts "  - 항 수: #{Clause.count}"
      
    else
      puts "\n❌ 샘플 임포트 테스트 실패"
      exit 1
    end
  end

  desc "Import partial regulation data for testing"
  task :import_partial, [:lines] => :environment do |task, args|
    lines = (args[:lines] || 1000).to_i
    full_file = Rails.root.join('regulations9-340-20250702.txt')
    test_file = Rails.root.join('tmp', "test_regulations_#{lines}.txt")
    
    puts "🧪 부분 데이터 임포트 테스트 (#{lines}라인)"
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
    
    # 임포터 서비스 로드
    require Rails.root.join('lib', 'services', 'regulation_parser')
    require Rails.root.join('lib', 'services', 'parser_benchmark')
    require Rails.root.join('lib', 'services', 'regulation_parser_service')
    require Rails.root.join('lib', 'services', 'regulation_importer')
    
    # 임포트 실행
    importer = RegulationImporter.new
    success = importer.import_from_file(test_file)
    
    if success
      puts "\n🎉 부분 임포트 테스트 완료!"
      
      # 데이터베이스 확인
      puts "\n📊 데이터베이스 현황:"
      puts "  - 편 수: #{Edition.count}"
      puts "  - 장 수: #{Chapter.count}"
      puts "  - 규정 수: #{Regulation.count}"
      puts "  - 조문 수: #{Article.count}"
      puts "  - 항 수: #{Clause.count}"
      
      # 결과를 JSON 파일로 저장
      output_file = Rails.root.join('tmp', "import_result_#{lines}.json")
      File.write(output_file, importer.to_json)
      puts "📄 결과 저장: #{output_file}"
      
    else
      puts "\n❌ 부분 임포트 테스트 실패"
    end
    
    # 임시 파일 정리
    File.delete(test_file) if File.exist?(test_file)
    puts "🗑️ 임시 파일 정리 완료"
  end

  desc "Clear all regulation data from database"
  task :clear => :environment do
    puts "🗑️ 규정 데이터 삭제 중..."
    
    ActiveRecord::Base.transaction do
      Clause.delete_all
      Article.delete_all
      Regulation.delete_all
      Chapter.delete_all
      Edition.delete_all
      
      puts "✅ 모든 규정 데이터 삭제 완료"
      
      # 시퀀스 리셋
      ActiveRecord::Base.connection.reset_pk_sequence!('clauses')
      ActiveRecord::Base.connection.reset_pk_sequence!('articles')
      ActiveRecord::Base.connection.reset_pk_sequence!('regulations')
      ActiveRecord::Base.connection.reset_pk_sequence!('chapters')
      ActiveRecord::Base.connection.reset_pk_sequence!('editions')
      
      puts "✅ 시퀀스 리셋 완료"
    end
  end

  desc "Show regulation import help"
  task :help do
    puts "📚 규정 임포트 사용법"
    puts "=" * 60
    puts ""
    puts "사용 가능한 작업:"
    puts ""
    puts "1. 샘플 데이터 임포트 테스트:"
    puts "   rails regulation:import_sample"
    puts ""
    puts "2. 부분 데이터 임포트 테스트 (기본 1000라인):"
    puts "   rails regulation:import_partial"
    puts "   rails regulation:import_partial[5000]"
    puts ""
    puts "3. 전체 데이터 임포트:"
    puts "   rails regulation:import"
    puts "   rails regulation:import[/path/to/file.txt]"
    puts ""
    puts "4. 데이터베이스 초기화:"
    puts "   rails regulation:clear"
    puts ""
    puts "5. 도움말:"
    puts "   rails regulation:help"
    puts ""
    puts "📁 결과 파일은 tmp/ 디렉토리에 저장됩니다."
    puts "📄 에러가 발생하면 CSV 로그 파일이 생성됩니다."
    puts ""
  end
end