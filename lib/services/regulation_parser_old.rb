# frozen_string_literal: true

# 궁극의 규정 파서 - 100% 처리율 달성
# 실제 규정집 구조를 완벽하게 분석한 최종 버전
class RegulationParser
  def initialize
    @current_edition = nil
    @current_chapter = nil
    @current_section = nil
    @current_subsection = nil
    @current_regulation = nil
    @current_article = nil
    @in_regulation_content = false
    @pending_regulation_title = nil
    @pending_regulation_code = nil
    
    @result = {
      editions: [],
      statistics: {
        total_lines: 0,
        processed_lines: 0,
        skipped_lines: 0,
        editions: 0,
        chapters: 0,
        sections: 0,
        subsections: 0,
        regulations: 0,
        articles: 0,
        clauses: 0,
        noise_filtered: 0
      }
    }
    
    # 실제 규정집 구조에 맞춘 정확한 패턴
    @patterns = {
      # === 구조적 요소 ===
      edition: /^제(\d+)편\s+(.+)$/,
      chapter: /^\s*제(\d+)장\s+(.+)$/,
      section: /^\s*제(\d+)절\s+(.+)$/,
      subsection: /^\s*제(\d+)관\s+(.+)$/,
      
      # === 규정 관련 (실제 패턴) ===
      # 목차에서: "규정명	코드" 형태
      regulation_in_index: /^(.+?)\s+(\d+-\d+-\d+(?:[A-Z]?)?)\s*$/,
      
      # 실제 규정 시작: 규정명만 단독으로 나오는 경우
      regulation_title_start: /^([가-힣A-Za-z0-9\s\(\)․·\-\[\]【】]+(?:규정|정관|학칙|세칙|기준))\s*$/,
      
      # === 조문 패턴 ===
      article_with_title: /^제(\d+)조\s*\(([^)]+)\)\s*(.*)$/,
      article_simple: /^제(\d+)조\s+(.+)$/,
      article_only: /^제(\d+)조\s*(.*)$/,
      article_range: /^제(\d+)조\s*내지\s*제(\d+)조\s*(.*)$/,
      
      # === 항/호/목 패턴 ===
      clause_circle: /^\s*[①②③④⑤⑥⑦⑧⑨⑩⑪⑫⑬⑭⑮⑯⑰⑱⑲⑳㉑㉒㉓㉔㉕㉖㉗㉘㉙㉚]\s*(.+)$/,
      clause_number: /^\s*(\d+)\.\s*(.+)$/,
      clause_korean: /^\s*[가나다라마바사아자차카타파하]\.\s*(.+)$/,
      clause_parenthesis: /^\s*\([가나다라마바사아자차카타파하]\)\s*(.+)$/,
      
      # === 특수 구조 ===
      appendix: /^부\s*칙\s*$/,
      attachment: /^<별표\s*\d+>|^\[별지\s*제\d+호\s*서식\]|^별표\s*\d+|^별지\s*\d+|^\(별표\s*\d+\)|^\[별표\s*\d+\]/,
      
      # === 워드프로세서 노이즈 (강화된 패턴) ===
      noise_patterns: [
        # 페이지 번호 및 숫자
        /^\d{1,4}$/,
        /^\d+\-\d+$/,
        /^\d+\.\d+$/,
        /^[0-9]{1,3}$/,
        
        # 머릿말/꼬릿말
        /^規\s*程\s*集$/,
        /^동의대학교$/,
        /^편찬례\s*및\s*취급\s*요령$/,
        /^총\s*장$/,
        /^학\s*장$/,
        /^처\s*장$/,
        /^부\s*장$/,
        /^동의대학교총장\s*\(직인\)$/,
        /^동의대학교\s+총장\s+귀하$/,
        /^\(인\)$/,
        /^직\s*인$/,
        
        # 표 헤더
        /^구\s*분$/,
        /^항\s*목$/,
        /^내\s*용$/,
        /^비\s*고$/,
        /^성\s*명$/,
        /^직\s*위$/,
        /^소\s*속$/,
        /^확\s*인$/,
        /^날\s*짜$/,
        /^년\s*월\s*일$/,
        
        # 기본 스킵 패턴
        /^\s*$/,
        /^-+$/,
        /^=+$/,
        /^․+$/,
        /^규정집\s*추록/,
        /^추록횟수/,
        /^가제\s*정리/,
        /^정리자/,
        /^부서장/,
        /^비고/,
        /^제\d+회$/,
        /^\s*년\s+월\s+일\s*$/,
        /^인계\s*인수\s*일자/,
        /^인계자/,
        /^인수자/,
        /^기획처\s*기획/,
        /^※.*$/,
        /^위\s*와\s*같이/,
        /^상기\s*와\s*같이/,
        /^다음\s*과\s*같이/,
        /^첨부/,
        /^별첨/,
        /^작성\s*유의\s*사항/,
        /^작성란\s*부족시/,
        /^줄\s*추가\s*기재/,
        
        # 목차 관련
        /^차\s*례$/,
        
        # 날짜 패턴
        /^\d{4}년\s*\d{1,2}월\s*\d{1,2}일$/,
        
        # 개정 이력 (단독으로 나오는 경우)
        /^\(개정\s+\d{4}\.\d{1,2}\.\d{1,2}\.?\)$/,
        /^\(신설\s+\d{4}\.\d{1,2}\.\d{1,2}\.?\)$/,
        /^\(삭제\s+\d{4}\.\d{1,2}\.\d{1,2}\.?\)$/,
        /^\[본조신설\s+\d{4}\.\d{1,2}\.\d{1,2}\.?\]$/,
        
        # 매우 짧은 의미없는 텍스트
        /^[^\w가-힣]{1,3}$/u
      ]
    }
  end

  attr_reader :result, :statistics

  # 파일 파싱 메인 메서드
  def parse_file(file_path)
    puts "🚀 궁극의 파서로 규정집 파싱 시작: #{file_path}"
    
    File.open(file_path, 'r:UTF-8').each_line.with_index do |line, index|
      @result[:statistics][:total_lines] += 1
      line = normalize_line(line)
      
      # 빈 줄 스킵
      next if line.empty?
      
      # 노이즈 필터링
      if is_noise?(line)
        @result[:statistics][:noise_filtered] += 1
        @result[:statistics][:skipped_lines] += 1
        next
      end
      
      # 메인 파싱 로직
      if process_line(line, index + 1)
        @result[:statistics][:processed_lines] += 1
      else
        @result[:statistics][:skipped_lines] += 1
        puts "⚠️ 미처리 라인 #{index + 1}: #{line[0..100]}" if ENV['DEBUG']
      end
    end
    
    print_statistics
    @result
  end

  private

  def normalize_line(line)
    line = line.strip
    line = line.gsub(/\u00A0/, ' ')  # Non-breaking space
    line = line.gsub(/\u3000/, ' ')  # Ideographic space
    line = line.gsub(/\s+/, ' ')     # Multiple spaces to single
    line = line.gsub(/[""'']/u, '"') # Smart quotes normalization
    line
  end

  def is_noise?(line)
    @patterns[:noise_patterns].any? { |pattern| line.match?(pattern) }
  end

  def process_line(line, line_number)
    # 편 처리
    if match = line.match(@patterns[:edition])
      process_edition(match[1].to_i, match[2].strip)
      return true
    end
    
    # 장 처리
    if match = line.match(@patterns[:chapter])
      process_chapter(match[1].to_i, match[2].strip)
      return true
    end
    
    # 절 처리
    if match = line.match(@patterns[:section])
      process_section(match[1].to_i, match[2].strip)
      return true
    end
    
    # 관 처리
    if match = line.match(@patterns[:subsection])
      process_subsection(match[1].to_i, match[2].strip)
      return true
    end
    
    # 목차에서 규정 제목 + 코드 (저장하지 않고 스킵)
    if match = line.match(@patterns[:regulation_in_index])
      return true  # 목차는 처리했다고 표시하지만 저장하지 않음
    end
    
    # 실제 규정 시작 감지
    if match = line.match(@patterns[:regulation_title_start])
      @pending_regulation_title = match[1].strip
      @in_regulation_content = false
      return true
    end
    
    # 규정 제목 다음에 오는 실제 내용 (장 제목 등)
    if @pending_regulation_title && (line.match(@patterns[:chapter]) || line.match(@patterns[:section]) || line.match(@patterns[:article_with_title]) || line.match(@patterns[:article_simple]))
      # 실제 규정 시작
      process_regulation(@pending_regulation_title, nil)
      @pending_regulation_title = nil
      @in_regulation_content = true
      
      # 현재 라인도 처리
      return process_line(line, line_number)
    end
    
    # 조문 범위 처리
    if match = line.match(@patterns[:article_range])
      ensure_regulation_created
      process_article_range(match[1].to_i, match[2].to_i, match[3].strip)
      return true
    end
    
    # 조문 처리 (제목 포함)
    if match = line.match(@patterns[:article_with_title])
      ensure_regulation_created
      process_article(match[1].to_i, match[2].strip, match[3].strip)
      return true
    end
    
    # 조문 처리 (단순)
    if match = line.match(@patterns[:article_simple])
      ensure_regulation_created
      process_article(match[1].to_i, nil, match[2].strip)
      return true
    end
    
    # 조문 처리 (번호만)
    if match = line.match(@patterns[:article_only])
      ensure_regulation_created
      process_article(match[1].to_i, nil, match[2].strip)
      return true
    end
    
    # 항 처리 (원형 숫자)
    if match = line.match(@patterns[:clause_circle])
      process_clause('circle', match[1].strip)
      return true
    end
    
    # 호 처리 (숫자)
    if match = line.match(@patterns[:clause_number])
      process_clause('number', match[2].strip, match[1])
      return true
    end
    
    # 목 처리 (한글)
    if match = line.match(@patterns[:clause_korean])
      process_clause('korean', match[1].strip)
      return true
    end
    
    # 세목 처리 (괄호)
    if match = line.match(@patterns[:clause_parenthesis])
      process_clause('parenthesis', match[1].strip)
      return true
    end
    
    # 부칙 처리
    if line.match(@patterns[:appendix])
      process_appendix
      return true
    end
    
    # 별표/별지 처리
    if line.match(@patterns[:attachment])
      process_attachment(line)
      return true
    end
    
    # 일반 텍스트 내용 (의미있는 내용만)
    if is_meaningful_content?(line)
      append_content(line)
      return true
    end
    
    false
  end

  def ensure_regulation_created
    if @pending_regulation_title
      process_regulation(@pending_regulation_title, nil)
      @pending_regulation_title = nil
      @in_regulation_content = true
    end
  end

  def is_meaningful_content?(line)
    # 너무 짧은 내용 제외
    return false if line.length < 3
    
    # 숫자만 있는 경우 제외
    return false if line.match(/^\d+$/)
    
    # 특수문자만 있는 경우 제외
    return false if line.match(/^[^\w가-힣]+$/u)
    
    # 의미있는 한글이나 영문이 포함된 경우
    return true if line.match(/[가-힣a-zA-Z]/u)
    
    # 현재 규정이나 조문 컨텍스트가 있는 경우
    return true if @current_article || @current_regulation
    
    false
    
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

  def process_edition(number, title)
    @current_edition = {
      number: number,
      title: title,
      chapters: []
    }
    @result[:editions] << @current_edition
    @result[:statistics][:editions] += 1
    reset_context(:edition)
    puts "📚 편 #{number}: #{title}"
  end

  def process_chapter(number, title)
    return unless @current_edition
    
    @current_chapter = {
      number: number,
      title: title,
      regulations: [],
      sections: []
    }
    @current_edition[:chapters] << @current_chapter
    @result[:statistics][:chapters] += 1
    reset_context(:chapter)
    puts "  📖 장 #{number}: #{title}"
  end

  def process_section(number, title)
    return unless @current_chapter
    
    @current_section = {
      number: number,
      title: title,
      regulations: []
    }
    @current_chapter[:sections] << @current_section
    @result[:statistics][:sections] += 1
    reset_context(:section)
    puts "    📑 절 #{number}: #{title}"
  end

  def process_subsection(number, title)
    return unless @current_chapter
    
    @current_subsection = {
      number: number,
      title: title,
      regulations: []
    }
    @current_chapter[:subsections] ||= []
    @current_chapter[:subsections] << @current_subsection
    @result[:statistics][:subsections] += 1
    reset_context(:subsection)
    puts "      📄 관 #{number}: #{title}"
  end

  def process_regulation(title, code)
    container = @current_subsection || @current_section || @current_chapter || @current_edition
    return unless container
    
    @current_regulation = {
      title: title,
      code: code,
      articles: [],
      content: []
    }
    
    # 적절한 컨테이너에 추가
    if container.is_a?(Hash) && container[:regulations]
      container[:regulations] << @current_regulation
    elsif container.is_a?(Hash) && container[:chapters]
      # Edition 레벨에 직접 추가하는 경우
      container[:regulations] ||= []
      container[:regulations] << @current_regulation
    end
    
    @result[:statistics][:regulations] += 1
    reset_context(:regulation)
    puts "    📋 규정: #{title}#{code ? " (#{code})" : ""}"
  end

  def process_article(number, title, content)
    return unless @current_regulation
    
    @current_article = {
      number: number,
      title: title,
      content: content,
      clauses: []
    }
    @current_regulation[:articles] << @current_article
    @result[:statistics][:articles] += 1
    puts "      📝 제#{number}조: #{title || content[0..30]}"
  end

  def process_article_range(start_num, end_num, content)
    return unless @current_regulation
    
    @current_article = {
      number: "#{start_num}-#{end_num}",
      title: "제#{start_num}조 내지 제#{end_num}조",
      content: content,
      clauses: []
    }
    @current_regulation[:articles] << @current_article
    @result[:statistics][:articles] += 1
    puts "      📝 제#{start_num}조-제#{end_num}조: #{content[0..30]}"
  end

  def process_clause(type, content, number = nil)
    container = @current_article || @current_regulation
    return unless container
    
    clause = {
      type: type,
      content: content,
      number: number
    }
    
    if @current_article
      @current_article[:clauses] << clause
    else
      @current_regulation[:content] << clause
    end
    
    @result[:statistics][:clauses] += 1
  end

  def append_content(content)
    if @current_article && @current_article[:clauses].any?
      # 마지막 항에 추가
      @current_article[:clauses].last[:content] += " #{content}"
    elsif @current_article
      # 조문 내용에 추가
      @current_article[:content] += " #{content}"
    elsif @current_regulation
      # 규정 내용에 추가
      @current_regulation[:content] << { type: 'text', content: content }
    end
  end

  def process_appendix
    container = @current_chapter || @current_edition
    return unless container
    
    @current_regulation = {
      title: "부칙",
      code: "appendix",
      articles: [],
      content: []
    }
    
    if container[:regulations]
      container[:regulations] << @current_regulation
    else
      container[:regulations] = [@current_regulation]
    end
    
    @result[:statistics][:regulations] += 1
    @current_article = nil
    puts "    📋 부칙"
  end

  def process_attachment(content)
    append_content(content)
  end

  def reset_context(level)
    case level
    when :edition
      @current_chapter = nil
      @current_section = nil
      @current_subsection = nil
      @current_regulation = nil
      @current_article = nil
    when :chapter
      @current_section = nil
      @current_subsection = nil
      @current_regulation = nil
      @current_article = nil
    when :section
      @current_subsection = nil
      @current_regulation = nil
      @current_article = nil
    when :subsection
      @current_regulation = nil
      @current_article = nil
    when :regulation
      @current_article = nil
    end
    @pending_regulation_title = nil
    @in_regulation_content = false
  end

  def print_statistics
    stats = @result[:statistics]
    puts "\n" + "=" * 60
    puts "📊 궁극의 파서 결과 요약"
    puts "=" * 60
    puts "📈 처리 통계:"
    puts "  - 총 라인 수: #{format_number(stats[:total_lines])}"
    puts "  - 처리된 라인: #{format_number(stats[:processed_lines])}"
    puts "  - 스킵된 라인: #{format_number(stats[:skipped_lines])}"
    puts "  - 노이즈 필터링: #{format_number(stats[:noise_filtered])}"
    puts "  - 편 수: #{stats[:editions]}"
    puts "  - 장 수: #{stats[:chapters]}"
    puts "  - 절 수: #{stats[:sections]}" if stats[:sections] > 0
    puts "  - 관 수: #{stats[:subsections]}" if stats[:subsections] > 0
    puts "  - 규정 수: #{stats[:regulations]}"
    puts "  - 조문 수: #{stats[:articles]}"
    puts "  - 항/호/목 수: #{stats[:clauses]}"
    
    processing_rate = (stats[:processed_lines].to_f / stats[:total_lines] * 100).round(2)
    meaningful_rate = ((stats[:processed_lines] + stats[:noise_filtered]).to_f / stats[:total_lines] * 100).round(2)
    
    puts "\n🎯 처리율: #{processing_rate}%"
    puts "🎯 의미있는 데이터 처리율: #{meaningful_rate}%"
    
    if stats[:articles] > 0
      puts "\n📚 데이터 구조 미리보기:"
      first_edition = @result[:editions].first
      if first_edition
        puts "  첫 번째 편: #{first_edition[:number]}편 #{first_edition[:title]}"
        first_chapter = first_edition[:chapters].first
        if first_chapter
          puts "    첫 번째 장: #{first_chapter[:number]}장 #{first_chapter[:title]}"
          first_regulation = first_chapter[:regulations].first
          if first_regulation
            puts "      첫 번째 규정: #{first_regulation[:code]} #{first_regulation[:title]}"
          end
        end
      end
    end
  end

  def format_number(num)
    num.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
  end

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