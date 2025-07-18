# frozen_string_literal: true

# 대화 제목 자동 생성 서비스 (Task 9 요구사항)
class TitleGeneratorService
  MAX_TITLE_LENGTH = 20
  DEFAULT_TITLE = "새 대화"
  
  def self.generate_from_message(message_content)
    new.generate_from_message(message_content)
  end
  
  def initialize
    # 제목 생성에 사용할 불용어 목록
    @stop_words = %w[
      은 는 이 가 을 를 에 에서 로 으로 와 과 의 도 만 부터 까지
      하다 있다 없다 되다 이다 아니다 그리다 같다 다르다
      그 이 저 그것 이것 저것 여기 거기 저기 어디 언제 누구 무엇 어떻게 왜
      안녕 안녕하세요 안녕히 감사 감사합니다 죄송 죄송합니다 실례 실례합니다
      질문 문의 궁금 알고 싶다 물어보다 여쭤보다 확인 검토 검색
    ]
  end
  
  def generate_from_message(message_content)
    return DEFAULT_TITLE if message_content.blank?
    
    # 1. 기본 정리
    cleaned_content = clean_content(message_content)
    return DEFAULT_TITLE if cleaned_content.blank?
    
    # 2. 키워드 추출
    keywords = extract_keywords(cleaned_content)
    return DEFAULT_TITLE if keywords.empty?
    
    # 3. 제목 생성
    title = build_title(keywords)
    
    # 4. 길이 제한 적용
    truncate_title(title)
  end
  
  private
  
  def clean_content(content)
    # HTML 태그 제거
    content = content.gsub(/<[^>]*>/, '')
    
    # 특수문자 정리 (한글, 영문, 숫자, 공백만 유지)
    content = content.gsub(/[^\p{Hangul}\p{Latin}\p{Digit}\s]/, ' ')
    
    # 연속된 공백 정리
    content = content.gsub(/\s+/, ' ').strip
    
    content
  end
  
  def extract_keywords(content)
    # 단어 분리 (공백 기준)
    words = content.split(/\s+/)
    
    # 불용어 제거
    meaningful_words = words.reject { |word| @stop_words.include?(word.downcase) }
    
    # 너무 짧은 단어 제거 (1글자 제외)
    meaningful_words = meaningful_words.reject { |word| word.length < 2 }
    
    # 중복 제거하면서 순서 유지
    meaningful_words.uniq
  end
  
  def build_title(keywords)
    # 키워드가 많으면 앞의 몇 개만 사용
    selected_keywords = keywords.first(3)
    
    # 키워드들을 공백으로 연결
    title = selected_keywords.join(' ')
    
    # 제목이 너무 짧으면 보완
    if title.length < 5 && keywords.length > 3
      # 더 많은 키워드 사용
      title = keywords.first(5).join(' ')
    end
    
    title.presence || DEFAULT_TITLE
  end
  
  def truncate_title(title)
    if title.length <= MAX_TITLE_LENGTH
      title
    else
      # 단어 경계에서 자르기 시도
      truncated = title[0, MAX_TITLE_LENGTH - 1]
      
      # 마지막 공백 위치 찾기
      last_space = truncated.rindex(' ')
      
      if last_space && last_space > MAX_TITLE_LENGTH / 2
        # 단어 경계에서 자르고 ... 추가
        truncated[0, last_space] + '…'
      else
        # 강제로 자르고 ... 추가
        title[0, MAX_TITLE_LENGTH - 1] + '…'
      end
    end
  end
end