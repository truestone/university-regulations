# frozen_string_literal: true

require 'rails_helper'
require 'benchmark'

RSpec.describe 'Regulation Import Performance', type: :performance do
  let(:sample_file) { Rails.root.join('spec', 'fixtures', 'sample_regulation.txt') }

  before do
    clear_all_regulation_data
  end

  after do
    clear_all_regulation_data
  end

  describe '파싱 성능 테스트' do
    it '샘플 파일 파싱이 1초 이내에 완료된다' do
      # Given: 파서 서비스 준비
      parser_service = RegulationParserService.new

      # When: 벤치마크 측정
      time = Benchmark.realtime do
        result = parser_service.parse_file_with_benchmark(sample_file)
        expect(result).not_to be_nil
        expect(result[:metadata][:success_rate]).to eq(100.0)
      end

      # Then: 성능 기준 확인
      expect(time).to be < 1.0
      puts "파싱 시간: #{time.round(3)}초"
    end

    it '1000라인 파일 파싱이 5초 이내에 완료된다' do
      # Given: 대용량 테스트 파일 생성
      large_file = create_large_test_file(1000)
      parser_service = RegulationParserService.new

      # When: 벤치마크 측정
      time = Benchmark.realtime do
        result = parser_service.parse_file_with_benchmark(large_file)
        expect(result).not_to be_nil
        expect(result[:metadata][:success_rate]).to be >= 90.0
      end

      # Then: 성능 기준 확인
      expect(time).to be < 5.0
      puts "1000라인 파싱 시간: #{time.round(3)}초"

      # 정리
      File.delete(large_file)
    end
  end

  describe '임포트 성능 테스트' do
    it '샘플 데이터 임포트가 2초 이내에 완료된다' do
      # Given: 파싱된 데이터 준비
      parser_service = RegulationParserService.new
      parsed_result = parser_service.parse_file_with_benchmark(sample_file)
      importer = RegulationImporter.new

      # When: 벤치마크 측정
      time = Benchmark.realtime do
        success = importer.import_parsed_data(parsed_result)
        expect(success).to be true
      end

      # Then: 성능 기준 확인
      expect(time).to be < 2.0
      puts "임포트 시간: #{time.round(3)}초"

      # 데이터 확인
      expect(Edition.count).to be > 0
      expect(Regulation.count).to be > 0
    end
  end

  describe '메모리 사용량 테스트' do
    it '파싱 과정에서 메모리 누수가 없다' do
      # Given: 초기 메모리 측정
      GC.start
      initial_memory = memory_usage

      # When: 여러 번 파싱 실행
      parser_service = RegulationParserService.new
      5.times do
        result = parser_service.parse_file_with_benchmark(sample_file)
        expect(result).not_to be_nil
      end

      # Then: 메모리 사용량 확인
      GC.start
      final_memory = memory_usage
      memory_increase = final_memory - initial_memory

      # 10MB 이하 증가 허용
      expect(memory_increase).to be < 10 * 1024 * 1024
      puts "메모리 증가: #{(memory_increase / 1024.0 / 1024.0).round(2)} MB"
    end
  end

  describe '동시성 테스트' do
    it '여러 파싱 작업이 동시에 실행되어도 안전하다' do
      # Given: 여러 스레드 준비
      threads = []
      results = []
      mutex = Mutex.new

      # When: 동시 파싱 실행
      time = Benchmark.realtime do
        3.times do |i|
          threads << Thread.new do
            parser_service = RegulationParserService.new
            result = parser_service.parse_file_with_benchmark(sample_file)
            
            mutex.synchronize do
              results << result
            end
          end
        end

        threads.each(&:join)
      end

      # Then: 모든 결과 확인
      expect(results.size).to eq(3)
      results.each do |result|
        expect(result).not_to be_nil
        expect(result[:metadata][:success_rate]).to eq(100.0)
      end

      puts "동시 파싱 시간: #{time.round(3)}초"
    end
  end

  private

  def clear_all_regulation_data
    Clause.delete_all
    Article.delete_all
    Regulation.delete_all
    Chapter.delete_all
    Edition.delete_all
  end

  def create_large_test_file(line_count)
    large_file = Rails.root.join('tmp', 'performance_test_regulation.txt')
    
    File.open(large_file, 'w:UTF-8') do |f|
      f.puts "규정집"
      f.puts ""
      
      (1..line_count).each do |i|
        case i % 10
        when 1
          f.puts "제#{(i/100)+1}편 성능테스트편#{i}"
        when 2
          f.puts "제#{(i/50)+1}장 성능테스트장#{i}"
        when 3
          f.puts "성능테스트규정#{i}\t#{(i/100)+1}-#{(i/50)+1}-#{i}"
        when 4, 6, 8
          f.puts "제#{i}조 (성능테스트#{i}) 이것은 성능 테스트 조문 #{i}입니다."
        when 5, 7, 9
          f.puts "① 성능 테스트 항 #{i}입니다."
        else
          f.puts ""
        end
      end
    end
    
    large_file
  end

  def memory_usage
    if RUBY_PLATFORM =~ /darwin/ # macOS
      `ps -o rss= -p #{Process.pid}`.to_i * 1024
    else # Linux
      `ps -o rss= -p #{Process.pid}`.to_i * 1024
    end
  rescue
    0
  end
end