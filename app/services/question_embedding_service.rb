# frozen_string_literal: true

# 질문 임베딩 파이프라인 서비스
class QuestionEmbeddingService
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :question, :string
  attribute :preprocessed_text, :string
  attribute :embedding, :string
  attribute :token_count, :integer

  validates :question, presence: true, length: { minimum: 3, maximum: 1000 }

  # 질문 임베딩 생성 메인 메서드
  def self.generate_embedding(question, options = {})
    service = new(question: question)
    service.process(options)
  end

  def process(options = {})
    return nil unless valid?

    Rails.logger.info "Processing question embedding: #{question.truncate(100)}"

    begin
      # 1. 텍스트 전처리
      self.preprocessed_text = preprocess_text(question)
      
      # 2. 임베딩 생성
      self.embedding = generate_embedding_vector(preprocessed_text)
      
      # 3. 토큰 수 계산
      self.token_count = estimate_token_count(preprocessed_text)
      
      Rails.logger.info "Successfully generated embedding (#{token_count} tokens)"
      
      {
        embedding: embedding,
        preprocessed_text: preprocessed_text,
        token_count: token_count,
        original_question: question
      }
      
    rescue => e
      Rails.logger.error "Failed to generate question embedding: #{e.message}"
      raise e
    end
  end

  private

  # 텍스트 전처리
  def preprocess_text(text)
    # 1. 기본 정규화
    normalized = text.strip
                    .gsub(/\s+/, ' ')  # 연속 공백 제거
                    .gsub(/[^\w\s가-힣ㄱ-ㅎㅏ-ㅣ.,?!]/, '')  # 특수문자 제거 (한글, 영문, 숫자, 기본 문장부호만 유지)
    
    # 2. 질문 형태로 정규화
    normalized = normalize_question_format(normalized)
    
    # 3. 불용어 제거 (선택적)
    normalized = remove_stopwords(normalized) if should_remove_stopwords?
    
    # 4. 최종 정리
    normalized.strip
  end

  # 질문 형태로 정규화
  def normalize_question_format(text)
    # 질문 접두사 추가 (필요한 경우)
    unless text.match?(/[?？]$/) || text.match?(/^(무엇|어떻게|언제|어디서|왜|누가|어느|몇)/)
      # 규정 관련 질문임을 명시
      text = "#{text}에 대한 규정은 무엇인가요?"
    end
    
    text
  end

  # 불용어 제거
  def remove_stopwords(text)
    # 한국어 불용어 목록 (기본적인 것들만)
    stopwords = %w[
      은 는 이 가 을 를 에 에서 로 으로 와 과 의 도 만 부터 까지
      그 이 저 그것 이것 저것 여기 거기 저기
    ]
    
    # 불용어가 단독으로 있는 경우만 제거 (문맥 보존)
    words = text.split(/\s+/)
    filtered_words = words.reject { |word| stopwords.include?(word) && words.length > 3 }
    
    filtered_words.join(' ')
  end

  # 불용어 제거 여부 결정
  def should_remove_stopwords?
    # 질문이 충분히 긴 경우에만 불용어 제거
    preprocessed_text.split(/\s+/).length > 5
  end

  # 임베딩 벡터 생성
  def generate_embedding_vector(text)
    response = openai_client.embeddings(
      parameters: {
        model: embedding_model,
        input: text,
        encoding_format: 'float'
      }
    )

    embedding_data = response.dig('data', 0, 'embedding')
    
    unless embedding_data&.is_a?(Array) && embedding_data.length == 1536
      raise "Invalid embedding response: expected array of length 1536, got #{embedding_data&.class} with length #{embedding_data&.length}"
    end

    embedding_data
  end

  # 토큰 수 추정
  def estimate_token_count(text)
    # 간단한 토큰 수 추정 (실제로는 tiktoken 등을 사용하는 것이 좋음)
    # 한글: 1글자 ≈ 1토큰, 영어: 4글자 ≈ 1토큰
    korean_chars = text.scan(/[가-힣]/).length
    english_chars = text.scan(/[a-zA-Z]/).length
    other_chars = text.length - korean_chars - english_chars
    
    (korean_chars + (english_chars / 4.0) + (other_chars / 2.0)).ceil
  end

  # OpenAI 클라이언트
  def openai_client
    @openai_client ||= OpenAI::Client.new(
      access_token: Rails.application.credentials.openai_api_key || ENV['OPENAI_API_KEY'],
      log_errors: true
    )
  end

  # 임베딩 모델
  def embedding_model
    'text-embedding-3-small'
  end

  # 질문 유형 분석
  def analyze_question_type
    question_lower = question.downcase
    
    case question_lower
    when /^(무엇|뭐|what)/
      :what
    when /^(어떻게|how)/
      :how
    when /^(언제|when)/
      :when
    when /^(어디|where)/
      :where
    when /^(왜|why)/
      :why
    when /^(누가|who)/
      :who
    when /^(얼마|how much|how many)/
      :quantity
    else
      :general
    end
  end

  # 질문 복잡도 분석
  def analyze_question_complexity
    word_count = preprocessed_text.split(/\s+/).length
    
    case word_count
    when 0..3
      :simple
    when 4..8
      :medium
    when 9..15
      :complex
    else
      :very_complex
    end
  end

  # 질문 메타데이터 생성
  def generate_metadata
    {
      question_type: analyze_question_type,
      complexity: analyze_question_complexity,
      token_count: token_count,
      preprocessed: preprocessed_text != question,
      processed_at: Time.current
    }
  end
end