# frozen_string_literal: true

namespace :regulation do
  namespace :test do
    desc "Run comprehensive regulation import test scenarios"
    task :all => :environment do
      puts "🧪 규정 임포트 종합 테스트 시작"
      puts "=" * 60
      
      test_results = {
        parsing: false,
        import: false,
        retry: false,
        performance: false,
        integration: false
      }
      
      begin
        # 1. 파싱 테스트
        puts "\n1️⃣ 파싱 테스트 실행 중..."
        test_results[:parsing] = run_parsing_test
        
        # 2. 임포트 테스트
        puts "\n2️⃣ 임포트 테스트 실행 중..."
        test_results[:import] = run_import_test
        
        # 3. 재시도 테스트
        puts "\n3️⃣ 재시도 테스트 실행 중..."
        test_results[:retry] = run_retry_test
        
        # 4. 성능 테스트
        puts "\n4️⃣ 성능 테스트 실행 중..."
        test_results[:performance] = run_performance_test
        
        # 5. 통합 테스트
        puts "\n5️⃣ 통합 테스트 실행 중..."
        test_results[:integration] = run_integration_test
        
        # 결과 요약
        print_test_summary(test_results)
        
      rescue => e
        puts "\n❌ 테스트 실행 중 오류 발생: #{e.message}"
        puts e.backtrace.first(5)
        exit 1
      end
    end

    desc "Run parsing test scenario"
    task :parsing => :environment do
      puts "🔍 파싱 테스트 시나리오"
      puts "=" * 40
      
      success = run_parsing_test
      exit(success ? 0 : 1)
    end

    desc "Run import test scenario"
    task :import => :environment do
      puts "📥 임포트 테스트 시나리오"
      puts "=" * 40
      
      success = run_import_test
      exit(success ? 0 : 1)
    end

    desc "Run retry test scenario"
    task :retry => :environment do
      puts "🔄 재시도 테스트 시나리오"
      puts "=" * 40
      
      success = run_retry_test
      exit(success ? 0 : 1)
    end

    desc "Run performance test scenario"
    task :performance => :environment do
      puts "⚡ 성능 테스트 시나리오"
      puts "=" * 40
      
      success = run_performance_test
      exit(success ? 0 : 1)
    end

    desc "Run integration test scenario"
    task :integration => :environment do
      puts "🔗 통합 테스트 시나리오"
      puts "=" * 40
      
      success = run_integration_test
      exit(success ? 0 : 1)
    end

    desc "Generate test report"
    task :report => :environment do
      puts "📊 테스트 리포트 생성"
      puts "=" * 40
      
      generate_test_report
    end

    desc "Clean test data"
    task :clean => :environment do
      puts "🗑️ 테스트 데이터 정리"
      puts "=" * 40
      
      clean_test_data
      puts "✅ 테스트 데이터 정리 완료"
    end

    private

    def run_parsing_test
      begin
        # 파서 서비스 로드
        require Rails.root.join('lib', 'services', 'regulation_parser')
        require Rails.root.join('lib', 'services', 'parser_benchmark')
        require Rails.root.join('lib', 'services', 'regulation_parser_service')
        
        # 샘플 파일 파싱
        sample_file = Rails.root.join('spec', 'fixtures', 'sample_regulation.txt')
        
        unless File.exist?(sample_file)
          puts "  ❌ 샘플 파일을 찾을 수 없습니다: #{sample_file}"
          return false
        end
        
        parser_service = RegulationParserService.new
        result = parser_service.parse_file_with_benchmark(sample_file)
        
        if result && result[:metadata][:success_rate] == 100.0
          puts "  ✅ 파싱 테스트 성공"
          puts "    - 성공률: #{result[:metadata][:success_rate]}%"
          puts "    - 편 수: #{result[:statistics][:editions]}"
          puts "    - 규정 수: #{result[:statistics][:regulations]}"
          return true
        else
          puts "  ❌ 파싱 테스트 실패"
          return false
        end
        
      rescue => e
        puts "  ❌ 파싱 테스트 오류: #{e.message}"
        return false
      end
    end

    def run_import_test
      begin
        # 테스트 데이터 정리
        clean_test_data
        
        # 파싱 후 임포트
        sample_file = Rails.root.join('spec', 'fixtures', 'sample_regulation.txt')
        
        require Rails.root.join('lib', 'services', 'regulation_parser')
        require Rails.root.join('lib', 'services', 'parser_benchmark')
        require Rails.root.join('lib', 'services', 'regulation_parser_service')
        require Rails.root.join('lib', 'services', 'regulation_importer')
        
        parser_service = RegulationParserService.new
        parsed_result = parser_service.parse_file_with_benchmark(sample_file)
        
        importer = RegulationImporter.new
        success = importer.import_parsed_data(parsed_result)
        
        if success && importer.errors.empty?
          puts "  ✅ 임포트 테스트 성공"
          puts "    - 편 수: #{Edition.count}"
          puts "    - 장 수: #{Chapter.count}"
          puts "    - 규정 수: #{Regulation.count}"
          puts "    - 조문 수: #{Article.count}"
          puts "    - 항 수: #{Clause.count}"
          return true
        else
          puts "  ❌ 임포트 테스트 실패"
          puts "    - 에러 수: #{importer.errors.size}"
          return false
        end
        
      rescue => e
        puts "  ❌ 임포트 테스트 오류: #{e.message}"
        return false
      end
    end

    def run_retry_test
      begin
        require Rails.root.join('lib', 'services', 'regulation_retry_handler')
        
        # 테스트용 실패 데이터 생성
        failed_data = [
          {
            type: :regulation,
            timestamp: Time.current,
            errors: ["Test validation error"],
            data: {
              code: "test-code",
              title: "테스트 규정",
              content: "테스트 내용"
            }
          }
        ]
        
        retry_handler = RegulationRetryHandler.new
        retry_handler.retry_failed_imports(failed_data)
        
        if retry_handler.retry_stats[:total_retries] > 0
          puts "  ✅ 재시도 테스트 성공"
          puts "    - 총 재시도: #{retry_handler.retry_stats[:total_retries]}"
          puts "    - 성공한 재시도: #{retry_handler.retry_stats[:successful_retries]}"
          return true
        else
          puts "  ❌ 재시도 테스트 실패"
          return false
        end
        
      rescue => e
        puts "  ❌ 재시도 테스트 오류: #{e.message}"
        return false
      end
    end

    def run_performance_test
      begin
        require 'benchmark'
        
        sample_file = Rails.root.join('spec', 'fixtures', 'sample_regulation.txt')
        
        require Rails.root.join('lib', 'services', 'regulation_parser')
        require Rails.root.join('lib', 'services', 'parser_benchmark')
        require Rails.root.join('lib', 'services', 'regulation_parser_service')
        
        parser_service = RegulationParserService.new
        
        # 파싱 성능 측정
        parsing_time = Benchmark.realtime do
          result = parser_service.parse_file_with_benchmark(sample_file)
          raise "파싱 실패" unless result
        end
        
        if parsing_time < 2.0 # 2초 이내
          puts "  ✅ 성능 테스트 성공"
          puts "    - 파싱 시간: #{parsing_time.round(3)}초"
          return true
        else
          puts "  ❌ 성능 테스트 실패"
          puts "    - 파싱 시간: #{parsing_time.round(3)}초 (기준: 2초)"
          return false
        end
        
      rescue => e
        puts "  ❌ 성능 테스트 오류: #{e.message}"
        return false
      end
    end

    def run_integration_test
      begin
        # 전체 파이프라인 테스트
        clean_test_data
        
        sample_file = Rails.root.join('spec', 'fixtures', 'sample_regulation.txt')
        
        # 1. 파싱
        require Rails.root.join('lib', 'services', 'regulation_parser')
        require Rails.root.join('lib', 'services', 'parser_benchmark')
        require Rails.root.join('lib', 'services', 'regulation_parser_service')
        require Rails.root.join('lib', 'services', 'regulation_importer')
        
        parser_service = RegulationParserService.new
        parsed_result = parser_service.parse_file_with_benchmark(sample_file)
        
        # 2. 임포트
        importer = RegulationImporter.new
        import_success = importer.import_parsed_data(parsed_result)
        
        # 3. 데이터 검증
        data_valid = Edition.count > 0 && Regulation.count > 0
        
        if parsed_result && import_success && data_valid
          puts "  ✅ 통합 테스트 성공"
          puts "    - 파싱 성공률: #{parsed_result[:metadata][:success_rate]}%"
          puts "    - 임포트 성공: #{import_success}"
          puts "    - 데이터 검증: #{data_valid}"
          return true
        else
          puts "  ❌ 통합 테스트 실패"
          return false
        end
        
      rescue => e
        puts "  ❌ 통합 테스트 오류: #{e.message}"
        return false
      end
    end

    def print_test_summary(results)
      puts "\n" + "=" * 60
      puts "📊 테스트 결과 요약"
      puts "=" * 60
      
      total_tests = results.size
      passed_tests = results.values.count(true)
      
      results.each do |test_name, success|
        status = success ? "✅ 통과" : "❌ 실패"
        puts "#{test_name.to_s.ljust(15)}: #{status}"
      end
      
      puts "\n🎯 전체 결과: #{passed_tests}/#{total_tests} 통과"
      
      if passed_tests == total_tests
        puts "🎉 모든 테스트가 성공했습니다!"
      else
        puts "⚠️ 일부 테스트가 실패했습니다."
        exit 1
      end
    end

    def generate_test_report
      report_file = Rails.root.join('tmp', "test_report_#{Time.current.strftime('%Y%m%d_%H%M%S')}.json")
      
      report_data = {
        generated_at: Time.current,
        environment: Rails.env,
        ruby_version: RUBY_VERSION,
        rails_version: Rails.version,
        database_records: {
          editions: Edition.count,
          chapters: Chapter.count,
          regulations: Regulation.count,
          articles: Article.count,
          clauses: Clause.count
        },
        test_files: {
          sample_file_exists: File.exist?(Rails.root.join('spec', 'fixtures', 'sample_regulation.txt')),
          integration_spec_exists: File.exist?(Rails.root.join('spec', 'integration', 'regulation_import_integration_spec.rb')),
          system_spec_exists: File.exist?(Rails.root.join('spec', 'system', 'regulation_import_system_spec.rb')),
          performance_spec_exists: File.exist?(Rails.root.join('spec', 'performance', 'regulation_import_performance_spec.rb'))
        }
      }
      
      File.write(report_file, JSON.pretty_generate(report_data))
      puts "📄 테스트 리포트 생성: #{report_file}"
    end

    def clean_test_data
      Clause.delete_all
      Article.delete_all
      Regulation.delete_all
      Chapter.delete_all
      Edition.delete_all
    end
  end
end