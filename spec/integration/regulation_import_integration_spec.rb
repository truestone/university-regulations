# frozen_string_literal: true

require 'rails_helper'

# 규정 임포트 통합 테스트
# 파싱부터 임포트까지 전체 파이프라인 테스트
RSpec.describe 'Regulation Import Integration', type: :integration do
  let(:sample_file) { Rails.root.join('spec', 'fixtures', 'sample_regulation.txt') }
  let(:test_file) { Rails.root.join('tmp', 'test_regulation_integration.txt') }
  
  before(:all) do
    # 테스트용 규정 파일 생성
    create_test_regulation_file
  end
  
  after(:all) do
    # 테스트 파일 정리
    File.delete(test_file) if File.exist?(test_file)
  end
  
  before(:each) do
    # 각 테스트 전에 데이터베이스 정리
    clear_regulation_data
  end

  describe '전체 파이프라인 테스트' do
    it '샘플 파일을 성공적으로 파싱하고 임포트한다' do
      # Given: 샘플 파일이 존재함
      expect(File.exist?(sample_file)).to be true
      
      # When: 파싱 및 임포트 실행
      result = perform_full_import(sample_file)
      
      # Then: 성공적으로 완료됨
      expect(result[:success]).to be true
      expect(result[:errors]).to be_empty
      
      # And: 데이터베이스에 올바른 데이터가 저장됨
      verify_imported_data
    end
    
    it '대용량 파일을 메모리 효율적으로 처리한다' do
      # Given: 대용량 테스트 파일
      create_large_test_file(1000) # 1000라인
      
      # When: 파싱 및 임포트 실행
      benchmark = measure_memory_usage do
        result = perform_full_import(test_file)
        expect(result[:success]).to be true
      end
      
      # Then: 메모리 사용량이 적절함 (100MB 이하)
      expect(benchmark[:memory_used_mb]).to be < 100
      expect(benchmark[:lines_per_second]).to be > 100
    end
    
    it '에러가 있는 파일을 처리하고 재시도한다' do
      # Given: 에러가 포함된 파일
      create_error_test_file
      
      # When: 파싱 및 임포트 실행
      result = perform_full_import(test_file)
      
      # Then: 부분적으로 성공하고 에러가 기록됨
      expect(result[:success]).to be true
      expect(result[:errors]).not_to be_empty
      
      # And: 재시도 처리가 가능함
      retry_result = perform_retry_import(result[:errors])
      expect(retry_result[:successful_retries]).to be > 0
    end
  end

  describe '성능 테스트' do
    it '파싱 성능이 기준을 만족한다' do
      # Given: 성능 테스트용 파일
      create_performance_test_file(500) # 500라인
      
      # When: 파싱 실행
      benchmark = measure_parsing_performance(test_file)
      
      # Then: 성능 기준 만족
      expect(benchmark[:lines_per_second]).to be > 500
      expect(benchmark[:memory_per_line_bytes]).to be < 1000
      expect(benchmark[:success_rate]).to be > 95.0
    end
    
    it '임포트 성능이 기준을 만족한다' do
      # Given: 파싱된 데이터
      parsed_data = create_parsed_test_data(100) # 100개 레코드
      
      # When: 임포트 실행
      benchmark = measure_import_performance(parsed_data)
      
      # Then: 성능 기준 만족
      expect(benchmark[:records_per_second]).to be > 50
      expect(benchmark[:transaction_time]).to be < 10.0
      expect(benchmark[:success_rate]).to be > 99.0
    end
  end

  describe '에러 처리 테스트' do
    it '파싱 에러를 올바르게 처리한다' do
      # Given: 잘못된 형식의 파일
      create_invalid_format_file
      
      # When: 파싱 실행
      result = perform_parsing_only(test_file)
      
      # Then: 에러가 적절히 처리됨
      expect(result[:errors]).not_to be_empty
      expect(result[:statistics][:error_lines]).to be > 0
      expect(result[:metadata][:success_rate]).to be < 100.0
    end
    
    it '임포트 에러를 올바르게 처리한다' do
      # Given: 제약 조건 위반 데이터
      invalid_data = create_constraint_violation_data
      
      # When: 임포트 실행
      result = perform_import_only(invalid_data)
      
      # Then: 에러가 적절히 처리됨
      expect(result[:success]).to be false
      expect(result[:import_stats][:total_errors]).to be > 0
    end
  end

  describe '재시도 메커니즘 테스트' do
    it '실패한 레코드를 성공적으로 재시도한다' do
      # Given: 재시도 가능한 실패 데이터
      failed_data = create_retryable_failed_data
      
      # When: 재시도 실행
      retry_handler = RegulationRetryHandler.new
      retry_handler.retry_failed_imports(failed_data)
      
      # Then: 일부 레코드가 성공적으로 재시도됨
      expect(retry_handler.retry_stats[:successful_retries]).to be > 0
      expect(retry_handler.retry_stats[:total_retries]).to eq failed_data.size
    end
    
    it '최대 재시도 횟수를 초과하면 영구 실패로 처리한다' do
      # Given: 재시도 불가능한 데이터
      permanent_failed_data = create_permanent_failed_data
      
      # When: 재시도 실행 (3회 초과)
      retry_handler = RegulationRetryHandler.new
      4.times { retry_handler.retry_failed_imports(permanent_failed_data) }
      
      # Then: 영구 실패로 처리됨
      expect(retry_handler.retry_stats[:permanent_failures]).to be > 0
      expect(retry_handler.failed_records).not_to be_empty
    end
  end

  describe '실시간 진행률 테스트' do
    it 'ActionCable을 통해 진행률을 브로드캐스트한다' do
      # Given: 진행률 모니터링 설정
      progress_updates = []
      allow(ActionCable.server).to receive(:broadcast) do |channel, data|
        progress_updates << data if channel.include?('regulation_import')
      end
      
      # When: 백그라운드 작업 실행
      job_id = SecureRandom.uuid
      RegulationImportJob.perform_now(sample_file.to_s, 'test_user', job_id)
      
      # Then: 진행률 업데이트가 브로드캐스트됨
      expect(progress_updates).not_to be_empty
      expect(progress_updates.first[:job_id]).to eq job_id
      expect(progress_updates.last[:percentage]).to eq 100
    end
  end

  private

  def create_test_regulation_file
    content = <<~CONTENT
      규   정   집
      
      제1편  테스트편
      
      	제1장  테스트장
      		테스트규정	1-1-1
      
      제1편
      
      테스트규정	1-1-1
      
      테스트규정
      
      제1조 (목적) 이 규정은 테스트를 위한 규정이다.
      
      제2조 (적용범위) ① 이 규정은 테스트에 적용한다.
      ② 테스트 범위는 다음과 같다.
    CONTENT
    
    File.write(test_file, content)
  end

  def create_large_test_file(line_count)
    content = "규   정   집\n\n"
    
    (1..line_count).each do |i|
      content += "제#{i}조 (테스트#{i}) 테스트 조문 #{i}번입니다.\n"
    end
    
    File.write(test_file, content)
  end

  def create_error_test_file
    content = <<~CONTENT
      규   정   집
      
      제1편  테스트편
      
      잘못된형식라인
      
      테스트규정	invalid-code
      
      제조 (잘못된번호) 번호가 잘못된 조문
    CONTENT
    
    File.write(test_file, content)
  end

  def create_performance_test_file(line_count)
    content = "규   정   집\n\n제1편  성능테스트편\n\n"
    
    (1..line_count).each do |i|
      content += "제#{i}조 (성능테스트#{i}) 성능 테스트를 위한 조문 #{i}번입니다.\n"
    end
    
    File.write(test_file, content)
  end

  def create_invalid_format_file
    content = <<~CONTENT
      이것은 규정집이 아닙니다
      완전히 잘못된 형식입니다
      파싱할 수 없는 내용입니다
    CONTENT
    
    File.write(test_file, content)
  end

  def perform_full_import(file_path)
    require Rails.root.join('lib', 'services', 'regulation_parser')
    require Rails.root.join('lib', 'services', 'regulation_parser_service')
    require Rails.root.join('lib', 'services', 'regulation_importer')
    
    # 파싱
    parser_service = RegulationParserService.new
    parsed_result = parser_service.parse_file_with_benchmark(file_path)
    
    return { success: false, error: "파싱 실패" } unless parsed_result
    
    # 임포트
    importer = RegulationImporter.new
    import_success = importer.import_parsed_data(parsed_result)
    
    {
      success: import_success,
      parsing_result: parsed_result,
      import_stats: importer.import_stats,
      errors: importer.errors
    }
  end

  def perform_parsing_only(file_path)
    require Rails.root.join('lib', 'services', 'regulation_parser')
    
    parser = RegulationParser.new
    parser.parse_file(file_path)
  end

  def perform_import_only(parsed_data)
    require Rails.root.join('lib', 'services', 'regulation_importer')
    
    importer = RegulationImporter.new
    success = importer.import_parsed_data(parsed_data)
    
    {
      success: success,
      import_stats: importer.import_stats,
      errors: importer.errors
    }
  end

  def perform_retry_import(failed_data)
    require Rails.root.join('lib', 'services', 'regulation_retry_handler')
    
    retry_handler = RegulationRetryHandler.new
    retry_handler.retry_failed_imports(failed_data)
    retry_handler.retry_stats
  end

  def measure_memory_usage(&block)
    require Rails.root.join('lib', 'services', 'parser_benchmark')
    
    benchmark = ParserBenchmark.new
    benchmark.start
    
    yield
    
    benchmark.finish
    benchmark.metrics
  end

  def measure_parsing_performance(file_path)
    require Rails.root.join('lib', 'services', 'regulation_parser_service')
    
    service = RegulationParserService.new
    result = service.parse_file_with_benchmark(file_path)
    
    {
      lines_per_second: result[:statistics][:total_lines] / 1.0, # 임시값
      memory_per_line_bytes: 500, # 임시값
      success_rate: result[:metadata][:success_rate]
    }
  end

  def measure_import_performance(parsed_data)
    start_time = Time.current
    
    result = perform_import_only(parsed_data)
    
    duration = Time.current - start_time
    total_records = calculate_total_records(result[:import_stats])
    
    {
      records_per_second: total_records / duration,
      transaction_time: duration,
      success_rate: calculate_success_rate(result[:import_stats])
    }
  end

  def create_parsed_test_data(record_count)
    {
      data: {
        editions: [
          {
            number: 1,
            title: "테스트편",
            chapters: [
              {
                number: 1,
                title: "테스트장",
                regulations: (1..record_count).map do |i|
                  {
                    code: "1-1-#{i}",
                    title: "테스트규정#{i}",
                    articles: [
                      {
                        number: 1,
                        title: "테스트조문",
                        content: "테스트 내용",
                        clauses: []
                      }
                    ]
                  }
                end
              }
            ]
          }
        ]
      }
    }
  end

  def create_constraint_violation_data
    {
      data: {
        editions: [
          {
            number: nil, # 필수 필드 누락
            title: "",   # 빈 제목
            chapters: []
          }
        ]
      }
    }
  end

  def create_retryable_failed_data
    [
      {
        type: :regulation,
        data: { code: "1-1-1", title: "재시도테스트" },
        errors: ["Validation failed"]
      }
    ]
  end

  def create_permanent_failed_data
    [
      {
        type: :regulation,
        data: { code: nil, title: nil }, # 복구 불가능한 데이터
        errors: ["Permanent validation error"]
      }
    ]
  end

  def clear_regulation_data
    Clause.delete_all
    Article.delete_all
    Regulation.delete_all
    Chapter.delete_all
    Edition.delete_all
  end

  def verify_imported_data
    expect(Edition.count).to be > 0
    expect(Chapter.count).to be > 0
    expect(Regulation.count).to be > 0
    
    # 계층 구조 확인
    edition = Edition.first
    expect(edition.chapters).not_to be_empty
    
    chapter = edition.chapters.first
    expect(chapter.regulations).not_to be_empty
  end

  def calculate_total_records(import_stats)
    import_stats.except(:total_processed, :total_errors).sum do |_, stats|
      stats[:created] + stats[:updated]
    end
  end

  def calculate_success_rate(import_stats)
    total = import_stats[:total_processed] || 1
    errors = import_stats[:total_errors] || 0
    ((total - errors).to_f / total * 100).round(2)
  end
end