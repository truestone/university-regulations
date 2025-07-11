# frozen_string_literal: true

# 규정 데이터 임포터 서비스
# 파싱된 데이터를 데이터베이스에 트랜잭션으로 삽입
class RegulationImporter
  attr_reader :import_stats, :errors, :batch_size

  def initialize(batch_size: 1000)
    @batch_size = batch_size
    @import_stats = {
      editions: { created: 0, updated: 0, failed: 0 },
      chapters: { created: 0, updated: 0, failed: 0 },
      regulations: { created: 0, updated: 0, failed: 0 },
      articles: { created: 0, updated: 0, failed: 0 },
      clauses: { created: 0, updated: 0, failed: 0 },
      total_processed: 0,
      total_errors: 0
    }
    @errors = []
  end

  # 파싱된 데이터를 데이터베이스에 임포트
  def import_parsed_data(parsed_result)
    puts "🚀 규정 데이터 임포트 시작"
    puts "=" * 60

    begin
      # 각 편별로 개별 트랜잭션 처리 (에러 격리)
      parsed_result[:data][:editions].each do |edition_data|
        ActiveRecord::Base.transaction do
          import_single_edition(edition_data)
        end
      end
      
      puts "\n✅ 임포트 완료!"
      print_import_summary
      
      true
    rescue => e
      puts "\n❌ 임포트 실패: #{e.message}"
      puts e.backtrace.first(5)
      
      @errors << {
        type: :transaction_error,
        message: e.message,
        timestamp: Time.current
      }
      
      false
    end
  end

  # 파일에서 직접 파싱하고 임포트
  def import_from_file(file_path)
    puts "📁 파일에서 임포트: #{file_path}"
    
    # 파서 로드
    require_relative 'regulation_parser'
    require_relative 'regulation_parser_service'
    
    # 파싱 실행
    service = RegulationParserService.new
    parsed_result = service.parse_file_with_benchmark(file_path)
    
    return false unless parsed_result
    
    # 임포트 실행
    import_parsed_data(parsed_result)
  end

  private

  def import_single_edition(edition_data)
    puts "\n📚 편 #{edition_data[:number]} 임포트 중..."
    
    begin
      edition = find_or_create_edition(edition_data)
      
      if edition.persisted?
        @import_stats[:editions][:created] += 1 if edition.created_at == edition.updated_at
        @import_stats[:editions][:updated] += 1 if edition.created_at != edition.updated_at
        
        # 하위 장 임포트
        import_chapters(edition, edition_data[:chapters]) if edition_data[:chapters]
        
        puts "  ✅ 편 #{edition_data[:number]} 임포트 완료"
      else
        handle_import_error(:edition, edition_data, edition.errors.full_messages)
        raise "Edition import failed"
      end
      
      @import_stats[:total_processed] += 1
      
    rescue => e
      handle_import_error(:edition, edition_data, [e.message])
      raise e
    end
  end

  def import_chapters(edition, chapters_data)
    return unless chapters_data&.any?
    
    chapters_data.each do |chapter_data|
      begin
        chapter = find_or_create_chapter(edition, chapter_data)
        
        if chapter.persisted?
          @import_stats[:chapters][:created] += 1 if chapter.created_at == chapter.updated_at
          @import_stats[:chapters][:updated] += 1 if chapter.created_at != chapter.updated_at
          
          # 하위 규정 임포트
          import_regulations(chapter, chapter_data[:regulations]) if chapter_data[:regulations]
        else
          handle_import_error(:chapter, chapter_data, chapter.errors.full_messages)
        end
        
      rescue => e
        handle_import_error(:chapter, chapter_data, [e.message])
      end
    end
  end

  def import_regulations(chapter, regulations_data)
    return unless regulations_data&.any?
    
    regulations_data.each do |regulation_data|
      begin
        regulation = find_or_create_regulation(chapter, regulation_data)
        
        if regulation.persisted?
          @import_stats[:regulations][:created] += 1 if regulation.created_at == regulation.updated_at
          @import_stats[:regulations][:updated] += 1 if regulation.created_at != regulation.updated_at
          
          # 하위 조문 임포트
          import_articles(regulation, regulation_data[:articles]) if regulation_data[:articles]
        else
          handle_import_error(:regulation, regulation_data, regulation.errors.full_messages)
        end
        
      rescue => e
        handle_import_error(:regulation, regulation_data, [e.message])
      end
    end
  end

  def import_articles(regulation, articles_data)
    return unless articles_data&.any?
    
    articles_data.each do |article_data|
      begin
        article = find_or_create_article(regulation, article_data)
        
        if article.persisted?
          @import_stats[:articles][:created] += 1 if article.created_at == article.updated_at
          @import_stats[:articles][:updated] += 1 if article.created_at != article.updated_at
          
          # 하위 항 임포트
          import_clauses(article, article_data[:clauses]) if article_data[:clauses]
        else
          handle_import_error(:article, article_data, article.errors.full_messages)
        end
        
      rescue => e
        handle_import_error(:article, article_data, [e.message])
      end
    end
  end

  def import_clauses(article, clauses_data)
    return unless clauses_data&.any?
    
    clauses_data.each do |clause_data|
      begin
        clause = find_or_create_clause(article, clause_data)
        
        if clause.persisted?
          @import_stats[:clauses][:created] += 1 if clause.created_at == clause.updated_at
          @import_stats[:clauses][:updated] += 1 if clause.created_at != clause.updated_at
        else
          handle_import_error(:clause, clause_data, clause.errors.full_messages)
        end
        
      rescue => e
        handle_import_error(:clause, clause_data, [e.message])
      end
    end
  end

  def find_or_create_edition(edition_data)
    Edition.find_or_initialize_by(number: edition_data[:number]).tap do |edition|
      edition.title = edition_data[:title]
      edition.description = edition_data[:description] if edition_data[:description]
      edition.sort_order = edition_data[:number]
      edition.is_active = true
      edition.save
    end
  end

  def find_or_create_chapter(edition, chapter_data)
    Chapter.find_or_initialize_by(
      edition: edition,
      number: chapter_data[:number]
    ).tap do |chapter|
      chapter.title = chapter_data[:title]
      chapter.description = chapter_data[:description] if chapter_data[:description]
      chapter.sort_order = chapter_data[:number]
      chapter.is_active = true
      chapter.save
    end
  end

  def find_or_create_regulation(chapter, regulation_data)
    Regulation.find_or_initialize_by(
      regulation_code: regulation_data[:code]
    ).tap do |regulation|
      regulation.chapter = chapter
      regulation.title = regulation_data[:title]
      regulation.content = regulation_data[:content] if regulation_data[:content]
      regulation.number = extract_regulation_number(regulation_data[:code])
      regulation.status = 'active'
      regulation.sort_order = regulation.number
      regulation.is_active = true
      regulation.save
    end
  end

  def find_or_create_article(regulation, article_data)
    Article.find_or_initialize_by(
      regulation: regulation,
      number: article_data[:number]
    ).tap do |article|
      article.title = article_data[:title]
      article.content = article_data[:content] if article_data[:content]
      article.sort_order = article_data[:number]
      article.is_active = true
      article.save
    end
  end

  def find_or_create_clause(article, clause_data)
    Clause.find_or_initialize_by(
      article: article,
      number: clause_data[:number]
    ).tap do |clause|
      clause.content = clause_data[:content]
      clause.clause_type = clause_data[:type] || 'paragraph'
      clause.sort_order = clause_data[:number]
      clause.is_active = true
      clause.save
    end
  end

  def extract_regulation_number(regulation_code)
    # 규정 코드에서 번호 추출 (예: "3-1-5" -> 5)
    parts = regulation_code.split('-')
    parts.last.to_i
  end

  def handle_import_error(type, data, error_messages)
    error = {
      type: type,
      data: data,
      errors: error_messages,
      timestamp: Time.current
    }
    
    @errors << error
    
    # import_stats 초기화 확인
    @import_stats[type] ||= { created: 0, updated: 0, failed: 0 }
    @import_stats[type][:failed] += 1
    @import_stats[:total_errors] += 1
    
    puts "  ❌ #{type.to_s.capitalize} 임포트 실패: #{error_messages.join(', ')}"
  end

  def print_import_summary
    puts "\n" + "=" * 60
    puts "📊 임포트 결과 요약"
    puts "=" * 60
    
    @import_stats.each do |key, value|
      next if key.in?([:total_processed, :total_errors])
      
      if value.is_a?(Hash)
        puts "#{key.to_s.capitalize}:"
        puts "  - 생성: #{value[:created]}"
        puts "  - 업데이트: #{value[:updated]}"
        puts "  - 실패: #{value[:failed]}"
        puts "  - 총계: #{value[:created] + value[:updated]}"
      end
    end
    
    puts "\n🎯 전체 통계:"
    puts "  - 총 처리: #{@import_stats[:total_processed]}"
    puts "  - 총 에러: #{@import_stats[:total_errors]}"
    
    success_rate = if @import_stats[:total_processed] > 0
                     ((@import_stats[:total_processed] - @import_stats[:total_errors]).to_f / @import_stats[:total_processed] * 100).round(2)
                   else
                     0.0
                   end
    puts "  - 성공률: #{success_rate}%"
    
    if @errors.any?
      puts "\n⚠️ 발생한 에러들 (최근 5개):"
      @errors.last(5).each do |error|
        puts "  - #{error[:type]}: #{error[:errors].join(', ')}"
      end
    end
  end

  # CSV로 에러 로그 저장
  def save_error_log(file_path = nil)
    file_path ||= Rails.root.join('tmp', "import_errors_#{Time.current.strftime('%Y%m%d_%H%M%S')}.csv")
    
    require 'csv'
    
    CSV.open(file_path, 'w') do |csv|
      csv << ['Type', 'Timestamp', 'Errors', 'Data']
      
      @errors.each do |error|
        csv << [
          error[:type],
          error[:timestamp],
          error[:errors].join('; '),
          error[:data].to_json
        ]
      end
    end
    
    puts "📄 에러 로그 저장: #{file_path}"
    file_path
  end

  # 임포트 통계를 JSON으로 반환
  def to_json
    {
      import_stats: @import_stats,
      errors: @errors,
      summary: {
        total_records: @import_stats.except(:total_processed, :total_errors).sum { |_, v| v[:created] + v[:updated] },
        success_rate: calculate_success_rate,
        generated_at: Time.current
      }
    }.to_json
  end

  private

  def calculate_success_rate
    return 100.0 if @import_stats[:total_processed] == 0
    
    successful = @import_stats[:total_processed] - @import_stats[:total_errors]
    (successful.to_f / @import_stats[:total_processed] * 100).round(2)
  end
end