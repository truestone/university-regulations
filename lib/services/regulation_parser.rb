# frozen_string_literal: true

# 규정집 파서 서비스
# 대용량 텍스트 파일을 상태머신 기반으로 파싱하여 구조화된 데이터로 변환
class RegulationParser
  # 파서 상태 정의
  module State
    INITIAL = :initial
    EDITION = :edition
    CHAPTER = :chapter
    REGULATION = :regulation
    ARTICLE = :article
    CLAUSE = :clause
    APPENDIX = :appendix
    SKIP = :skip
    ERROR = :error
  end

  # 정규식 패턴 정의
  PATTERNS = {
    edition: /^제(\d+)편\s+(.+)$/,
    chapter: /^제(\d+)장\s+(.+)$/,
    regulation: /^(.+)\s+(\d+-\d+-\d+)$/,
    article: /^제(\d+)조\s*\(([^)]+)\)\s*(.*)$/,
    clause: /^[①②③④⑤⑥⑦⑧⑨⑩]\s*(.+)$/,
    appendix: /^부\s*칙$/,
    table: /^<별표\s*\d+>|^\[별지\s*제\d+호\s*서식\]$/,
    date: /^\d{4}년\s*\d{1,2}월\s*\d{1,2}일$/,
    skip_patterns: [
      /^차\s*례$/,
      /^규정집/,
      /^편찬례/,
      /^\s*$/,
      /^-+$/,
      /^=+$/
    ]
  }.freeze

  attr_reader :current_state, :context, :errors, :statistics

  def initialize
    reset_parser
  end

  # 파일 파싱 메인 메서드
  def parse_file(file_path)
    reset_parser
    
    File.open(file_path, 'r:UTF-8') do |file|
      file.each_line.with_index(1) do |line, line_number|
        process_line(line.chomp, line_number)
        @statistics[:total_lines] += 1
      end
    end

    finalize_parsing
    build_result
  end

  private

  def reset_parser
    @current_state = State::INITIAL
    @context = {
      current_edition: nil,
      current_chapter: nil,
      current_regulation: nil,
      current_article: nil,
      current_clause: nil
    }
    @errors = []
    @statistics = {
      total_lines: 0,
      editions: 0,
      chapters: 0,
      regulations: 0,
      articles: 0,
      clauses: 0,
      skipped_lines: 0,
      error_lines: 0
    }
    @parsed_data = {
      editions: [],
      metadata: {}
    }
  end

  def process_line(line, line_number)
    # 빈 라인이나 스킵 패턴 체크
    return skip_line(line_number) if should_skip_line?(line)

    # 현재 상태에 따른 라인 처리
    case @current_state
    when State::INITIAL
      process_initial_state(line, line_number)
    when State::EDITION
      process_edition_state(line, line_number)
    when State::CHAPTER
      process_chapter_state(line, line_number)
    when State::REGULATION
      process_regulation_state(line, line_number)
    when State::ARTICLE
      process_article_state(line, line_number)
    when State::CLAUSE
      process_clause_state(line, line_number)
    when State::SKIP
      # 스킵 상태에서는 다른 패턴을 찾을 때까지 대기
      try_state_transition(line, line_number)
    else
      handle_error("Unknown state: #{@current_state}", line_number)
    end
  end

  def should_skip_line?(line)
    return true if line.strip.empty?
    
    PATTERNS[:skip_patterns].any? { |pattern| line.match?(pattern) }
  end

  def skip_line(line_number)
    @statistics[:skipped_lines] += 1
  end

  def process_initial_state(line, line_number)
    if (match = line.match(PATTERNS[:edition]))
      create_edition(match[1].to_i, match[2].strip, line_number)
      transition_to(State::EDITION)
    else
      transition_to(State::SKIP)
    end
  end

  def process_edition_state(line, line_number)
    if (match = line.match(PATTERNS[:edition]))
      create_edition(match[1].to_i, match[2].strip, line_number)
    elsif (match = line.match(PATTERNS[:chapter]))
      create_chapter(match[1].to_i, match[2].strip, line_number)
      transition_to(State::CHAPTER)
    elsif (match = line.match(PATTERNS[:regulation]))
      create_regulation(match[2], match[1].strip, line_number)
      transition_to(State::REGULATION)
    else
      transition_to(State::SKIP)
    end
  end

  def process_chapter_state(line, line_number)
    if (match = line.match(PATTERNS[:edition]))
      create_edition(match[1].to_i, match[2].strip, line_number)
      transition_to(State::EDITION)
    elsif (match = line.match(PATTERNS[:chapter]))
      create_chapter(match[1].to_i, match[2].strip, line_number)
    elsif (match = line.match(PATTERNS[:regulation]))
      create_regulation(match[2], match[1].strip, line_number)
      transition_to(State::REGULATION)
    else
      transition_to(State::SKIP)
    end
  end

  def process_regulation_state(line, line_number)
    if (match = line.match(PATTERNS[:article]))
      create_article(match[1].to_i, match[2].strip, match[3].strip, line_number)
      transition_to(State::ARTICLE)
    elsif (match = line.match(PATTERNS[:edition]))
      create_edition(match[1].to_i, match[2].strip, line_number)
      transition_to(State::EDITION)
    elsif (match = line.match(PATTERNS[:chapter]))
      create_chapter(match[1].to_i, match[2].strip, line_number)
      transition_to(State::CHAPTER)
    elsif (match = line.match(PATTERNS[:regulation]))
      create_regulation(match[2], match[1].strip, line_number)
    elsif line.match(PATTERNS[:appendix])
      transition_to(State::APPENDIX)
    else
      # 규정 내용으로 간주하고 현재 규정에 추가
      append_to_current_regulation(line) if @context[:current_regulation]
    end
  end

  def process_article_state(line, line_number)
    if (match = line.match(PATTERNS[:clause]))
      create_clause(extract_clause_number(line), match[1].strip, line_number)
      transition_to(State::CLAUSE)
    elsif (match = line.match(PATTERNS[:article]))
      create_article(match[1].to_i, match[2].strip, match[3].strip, line_number)
    elsif try_higher_level_transition(line, line_number)
      # 상위 레벨로 전환됨
    else
      # 조문 내용으로 간주하고 현재 조문에 추가
      append_to_current_article(line) if @context[:current_article]
    end
  end

  def process_clause_state(line, line_number)
    if (match = line.match(PATTERNS[:clause]))
      create_clause(extract_clause_number(line), match[1].strip, line_number)
    elsif (match = line.match(PATTERNS[:article]))
      create_article(match[1].to_i, match[2].strip, match[3].strip, line_number)
      transition_to(State::ARTICLE)
    elsif try_higher_level_transition(line, line_number)
      # 상위 레벨로 전환됨
    else
      # 항 내용으로 간주하고 현재 항에 추가
      append_to_current_clause(line) if @context[:current_clause]
    end
  end

  def try_higher_level_transition(line, line_number)
    if (match = line.match(PATTERNS[:edition]))
      create_edition(match[1].to_i, match[2].strip, line_number)
      transition_to(State::EDITION)
      true
    elsif (match = line.match(PATTERNS[:chapter]))
      create_chapter(match[1].to_i, match[2].strip, line_number)
      transition_to(State::CHAPTER)
      true
    elsif (match = line.match(PATTERNS[:regulation]))
      create_regulation(match[2], match[1].strip, line_number)
      transition_to(State::REGULATION)
      true
    else
      false
    end
  end

  def try_state_transition(line, line_number)
    if (match = line.match(PATTERNS[:edition]))
      create_edition(match[1].to_i, match[2].strip, line_number)
      transition_to(State::EDITION)
    elsif (match = line.match(PATTERNS[:chapter]))
      create_chapter(match[1].to_i, match[2].strip, line_number)
      transition_to(State::CHAPTER)
    elsif (match = line.match(PATTERNS[:regulation]))
      create_regulation(match[2], match[1].strip, line_number)
      transition_to(State::REGULATION)
    end
  end

  def create_edition(number, title, line_number)
    edition = {
      number: number,
      title: title,
      chapters: [],
      line_number: line_number
    }
    
    @parsed_data[:editions] << edition
    @context[:current_edition] = edition
    @context[:current_chapter] = nil
    @context[:current_regulation] = nil
    @context[:current_article] = nil
    @context[:current_clause] = nil
    
    @statistics[:editions] += 1
  end

  def create_chapter(number, title, line_number)
    return handle_error("No current edition for chapter", line_number) unless @context[:current_edition]

    chapter = {
      number: number,
      title: title,
      regulations: [],
      line_number: line_number
    }
    
    @context[:current_edition][:chapters] << chapter
    @context[:current_chapter] = chapter
    @context[:current_regulation] = nil
    @context[:current_article] = nil
    @context[:current_clause] = nil
    
    @statistics[:chapters] += 1
  end

  def create_regulation(code, title, line_number)
    # 편이나 장이 없는 경우 기본값 생성
    ensure_default_edition_and_chapter(line_number) unless @context[:current_chapter]

    regulation = {
      code: code,
      title: title,
      articles: [],
      content: "",
      line_number: line_number
    }
    
    @context[:current_chapter][:regulations] << regulation
    @context[:current_regulation] = regulation
    @context[:current_article] = nil
    @context[:current_clause] = nil
    
    @statistics[:regulations] += 1
  end

  def create_article(number, title, content, line_number)
    return handle_error("No current regulation for article", line_number) unless @context[:current_regulation]

    article = {
      number: number,
      title: title,
      content: content,
      clauses: [],
      line_number: line_number
    }
    
    @context[:current_regulation][:articles] << article
    @context[:current_article] = article
    @context[:current_clause] = nil
    
    @statistics[:articles] += 1
  end

  def create_clause(number, content, line_number)
    return handle_error("No current article for clause", line_number) unless @context[:current_article]

    clause = {
      number: number,
      content: content,
      type: determine_clause_type(content),
      line_number: line_number
    }
    
    @context[:current_article][:clauses] << clause
    @context[:current_clause] = clause
    
    @statistics[:clauses] += 1
  end

  def extract_clause_number(line)
    clause_markers = ['①', '②', '③', '④', '⑤', '⑥', '⑦', '⑧', '⑨', '⑩']
    clause_markers.each_with_index do |marker, index|
      return index + 1 if line.start_with?(marker)
    end
    1 # 기본값
  end

  def determine_clause_type(content)
    return 'subparagraph' if content.include?('다만') || content.include?('단서')
    return 'item' if content.match?(/^\d+\./) || content.match?(/^[가-힣]\./)
    'paragraph'
  end

  def append_to_current_regulation(line)
    @context[:current_regulation][:content] += "\n#{line}" if line.strip.length > 0
  end

  def append_to_current_article(line)
    @context[:current_article][:content] += "\n#{line}" if line.strip.length > 0
  end

  def append_to_current_clause(line)
    @context[:current_clause][:content] += "\n#{line}" if line.strip.length > 0
  end

  def ensure_default_edition_and_chapter(line_number)
    unless @context[:current_edition]
      create_edition(0, "기타", line_number)
    end
    
    unless @context[:current_chapter]
      create_chapter(0, "기타", line_number)
    end
  end

  def transition_to(new_state)
    @current_state = new_state
  end

  def handle_error(message, line_number)
    error = {
      message: message,
      line_number: line_number,
      state: @current_state,
      timestamp: Time.current
    }
    
    @errors << error
    @statistics[:error_lines] += 1
    
    # 에러 복구: SKIP 상태로 전환
    transition_to(State::SKIP)
  end

  def finalize_parsing
    # 파싱 완료 후 정리 작업
    clean_empty_content
    validate_hierarchy
  end

  def clean_empty_content
    @parsed_data[:editions].each do |edition|
      edition[:chapters].each do |chapter|
        chapter[:regulations].each do |regulation|
          regulation[:content] = regulation[:content].strip
          regulation[:articles].each do |article|
            article[:content] = article[:content].strip
            article[:clauses].each do |clause|
              clause[:content] = clause[:content].strip
            end
          end
        end
      end
    end
  end

  def validate_hierarchy
    # 계층 구조 검증 로직
    @parsed_data[:editions].each do |edition|
      next if edition[:chapters].empty?
      
      edition[:chapters].each do |chapter|
        next if chapter[:regulations].empty?
        
        chapter[:regulations].each do |regulation|
          # 규정 코드 검증
          unless regulation[:code].match?(/^\d+-\d+-\d+$/)
            @errors << {
              message: "Invalid regulation code: #{regulation[:code]}",
              line_number: regulation[:line_number],
              type: :validation_error
            }
          end
        end
      end
    end
  end

  def build_result
    {
      data: @parsed_data,
      statistics: @statistics,
      errors: @errors,
      metadata: {
        parsed_at: Time.current,
        parser_version: "1.0.0",
        total_errors: @errors.size,
        success_rate: calculate_success_rate
      }
    }
  end

  def calculate_success_rate
    return 100.0 if @statistics[:total_lines] == 0
    
    successful_lines = @statistics[:total_lines] - @statistics[:error_lines]
    (successful_lines.to_f / @statistics[:total_lines] * 100).round(2)
  end
end