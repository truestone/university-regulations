# frozen_string_literal: true

namespace :sample_data do
  desc "Generate sample questions and embeddings for testing"
  task :generate_questions => :environment do
    puts "🚀 샘플 질문 데이터 생성 시작"
    puts "=" * 60
    
    # 샘플 질문 목록
    sample_questions = [
      "대학교 등록금 납부 기한은 언제인가요?",
      "학생증 재발급 절차는 어떻게 되나요?",
      "휴학 신청은 언제까지 할 수 있나요?",
      "장학금 신청 자격 요건은 무엇인가요?",
      "기숙사 입사 신청 방법을 알려주세요",
      "성적 이의신청은 어떻게 하나요?",
      "졸업 요건은 무엇인가요?",
      "전과 신청 절차를 알려주세요",
      "수강신청 변경 기간은 언제인가요?",
      "도서관 이용 시간은 어떻게 되나요?",
      "학점 인정 기준은 무엇인가요?",
      "교환학생 프로그램 신청 방법은?",
      "학사경고 해제 조건은 무엇인가요?",
      "복수전공 신청 자격은?",
      "계절학기 수강료는 얼마인가요?",
      "학생회비 납부는 의무인가요?",
      "출석 인정 기준은 무엇인가요?",
      "시험 응시 자격 요건은?",
      "학위논문 제출 기한은 언제인가요?",
      "인턴십 학점 인정 기준은?"
    ]
    
    generated_count = 0
    failed_count = 0
    
    sample_questions.each_with_index do |question, index|
      begin
        puts "  처리 중: #{question}"
        
        # 임베딩 생성
        start_time = Time.current
        embedding_result = QuestionEmbeddingService.generate_embedding(question)
        end_time = Time.current
        
        if embedding_result
          # SearchQuery 로그 생성
          SearchQuery.log_search(
            query_text: question,
            embedding: embedding_result[:embedding],
            results_count: rand(0..10), # 임의의 결과 수
            response_time_ms: ((end_time - start_time) * 1000).round,
            metadata: {
              question_type: analyze_question_type(question),
              complexity: analyze_complexity(question),
              token_count: embedding_result[:token_count],
              sample_data: true
            }
          )
          
          generated_count += 1
          puts "    ✅ 성공 (#{generated_count}/#{sample_questions.length})"
        else
          failed_count += 1
          puts "    ❌ 실패"
        end
        
        # API 호출 제한을 위한 대기
        sleep(0.1) if index % 5 == 0
        
      rescue => e
        failed_count += 1
        puts "    ❌ 오류: #{e.message}"
      end
    end
    
    puts "\n" + "=" * 60
    puts "✅ 샘플 질문 데이터 생성 완료"
    puts "📊 성공: #{generated_count}개, 실패: #{failed_count}개"
    puts "📋 총 SearchQuery 레코드: #{SearchQuery.count}개"
  end

  desc "Generate performance test data"
  task :generate_performance_data => :environment do
    puts "🚀 성능 테스트 데이터 생성 시작"
    
    # 다양한 응답 시간과 결과 수를 가진 가상 데이터 생성
    100.times do |i|
      SearchQuery.create!(
        query_text: "테스트 질문 #{i + 1}",
        embedding: Array.new(1536, rand),
        results_count: rand(0..15),
        response_time_ms: rand(50..2000),
        metadata: {
          test_data: true,
          batch: 'performance_test',
          generated_at: Time.current
        },
        created_at: rand(30.days).seconds.ago
      )
      
      print "." if i % 10 == 0
    end
    
    puts "\n✅ 성능 테스트 데이터 100개 생성 완료"
  end

  desc "Show search analytics"
  task :analytics => :environment do
    puts "📊 검색 분석 리포트"
    puts "=" * 60
    
    # 성능 통계
    stats = SearchQuery.performance_stats
    puts "📈 성능 통계 (최근 1주일):"
    puts "  - 총 검색 수: #{stats[:total_queries]}"
    puts "  - 성공: #{stats[:successful_queries]}"
    puts "  - 실패: #{stats[:failed_queries]}"
    puts "  - 평균 응답시간: #{stats[:avg_response_time]}ms"
    puts "  - 평균 결과 수: #{stats[:avg_results_count]}"
    
    # 인기 검색어
    puts "\n🔥 인기 검색어 (최근 1주일):"
    SearchQuery.popular_queries.each_with_index do |item, index|
      puts "  #{index + 1}. #{item[:query]} (#{item[:count]}회)"
    end
    
    # 최근 검색
    puts "\n🕒 최근 검색 (최근 10개):"
    SearchQuery.recent.order(created_at: :desc).limit(10).each do |query|
      puts "  - #{query.query_text.truncate(50)} (#{query.created_at.strftime('%m/%d %H:%M')})"
    end
  end

  private

  def analyze_question_type(question)
    case question.downcase
    when /^(무엇|뭐|what)/
      'what'
    when /^(어떻게|how)/
      'how'
    when /^(언제|when)/
      'when'
    when /^(어디|where)/
      'where'
    when /^(왜|why)/
      'why'
    when /^(누가|who)/
      'who'
    else
      'general'
    end
  end

  def analyze_complexity(question)
    word_count = question.split(/\s+/).length
    
    case word_count
    when 0..3
      'simple'
    when 4..8
      'medium'
    when 9..15
      'complex'
    else
      'very_complex'
    end
  end
end