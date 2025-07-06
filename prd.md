# 대학 규정 관리 및 AI 검색 시스템 PRD

## 1. 프로젝트 개요

### 1.1. 목표

- **규정 관리**: 관리자가 대학 규정을 웹에서 생성, 수정, 삭제할 수 있는 시스템
- **AI 검색**: 사용자가 자연어로 질문하여 관련 규정을 찾을 수 있는 검색 시스템
- **데이터 동기화**: 규정 변경 시 AI 검색 데이터(임베딩)가 자동으로 업데이트되는 시스템

### 1.2. 배경

기존 텍스트 파일 기반의 규정 관리는 비효율적이고 오류 발생 가능성이 높습니다. 이를 체계적인 웹 시스템으로 전환하여 안정성을 높이고, AI 검색을 도입하여 사용자가 원하는 정보를 쉽게 찾을 수 있도록 개선하고자 합니다.

### 1.3. 핵심 기능

1. **관리자 기능**: 규정 CRUD, 임베딩 동기화, AI 설정 관리
2. **사용자 기능**: 자연어 질문, AI 답변, 대화형 검색
3. **데이터 관리**: 규정 텍스트 파싱, 계층 구조 관리, 벡터 검색

## 2. 기술 스택

### 2.1. 기본 기술 스택

- **Framework**: Ruby on Rails 8.0.x (최신 안정 버전)
- **Database**: PostgreSQL with pgvector extension
- **Frontend**: Rails Views + Tailwind CSS + Hotwire (Turbo)
- **AI Integration**: 
  - 로컬 개발: OpenAI API, Anthropic Claude API, Google Gemini API, 또는 로컬 LLM (Ollama, LM Studio, GPT4All 등)
  - 배포 환경: OpenAI API, Anthropic Claude API, 또는 Google Gemini API
- **Deployment**: Render (무료 호스팅)

### 2.2. 필수 Gem 목록

- `pg`, `pgvector` - PostgreSQL 벡터 확장
- `ruby-openai` - OpenAI API 연동
- `anthropic` - Anthropic Claude API 연동
- `googleauth`, `google-apis-aiplatform_v1` - Google Gemini API 연동
- `redis` - 캐싱 및 세션 관리
- `tailwindcss-rails` - CSS 프레임워크
- `turbo-rails` - 실시간 업데이트

## 3. 데이터베이스 설계

### 3.1. 원본 데이터 구조 분석

**동의대학교 규정집 구조:**
- **총 74,707줄의 텍스트 파일**
- **6편 구조**: 학교법인 → 학칙 → 행정규정 → 위원회규정 → 부속기관 → 산학협력단
- **계층적 번호 체계**: X-Y-Z (편-장-규정) 형태 (예: 3-1-65)
- **규정 상태 관리**: 【폐지】 표시된 규정들 존재
- **다양한 문서 형식**: 규정본문, 별표, 서식, 찾아보기 인덱스

### 3.2. 계층 구조 정의

**실제 데이터 기반 계층 관계:**
```
편(Edition) → 장(Chapter) → 규정(Regulation) → 조(Article) → 항/호(Clause)
```

**편(Edition) 구조:**
1. 제1편: 학교법인
2. 제2편: 학칙
3. 제3편: 행정규정
4. 제4편: 위원회규정  
5. 제5편: 부속기관
6. 제6편: 산학협력단

### 3.3. 핵심 모델 설계

**규정 관리 모델:**

1. **User**: 관리자 계정
   - `email` (string, unique): 이메일 (로그인 ID)
   - `password_digest` (string): 암호화된 비밀번호
   - `name` (string): 관리자 이름
   - `role` (string): 역할 (admin, super_admin)
   - `last_login_at` (datetime): 마지막 로그인 시간

2. **Edition**: 규정집 편
   - `number` (integer): 편 번호 (1-6)
   - `title` (string): 편 제목 (예: "학교법인", "학칙")
   - `description` (text): 편 설명
   - `sort_order` (integer): 정렬 순서
   - `is_active` (boolean): 활성 상태

3. **Chapter**: 규정집 장
   - `edition_id` (references): 소속 편
   - `number` (integer): 장 번호
   - `title` (string): 장 제목
   - `description` (text): 장 설명
   - `sort_order` (integer): 정렬 순서
   - `is_active` (boolean): 활성 상태

4. **Regulation**: 개별 규정
   - `chapter_id` (references): 소속 장
   - `number` (integer): 규정 번호 (편-장-규정 중 규정 부분)
   - `code` (string): 완전한 규정 코드 (예: "3-1-65")
   - `title` (string): 규정 제목
   - `status` (string): 상태 (active, abolished, superseded)
   - `abolished_at` (datetime): 폐지 일자
   - `superseded_by_id` (references): 대체 규정 ID
   - `enacted_at` (date): 제정 일자
   - `last_amended_at` (date): 최종 개정 일자
   - `department` (string): 소관 부서
   - `sort_order` (integer): 정렬 순서

5. **Article**: 규정의 조
   - `regulation_id` (references): 소속 규정
   - `number` (string): 조 번호 (예: "제1조", "제15조의2")
   - `title` (string): 조 제목
   - `content` (text): 조 내용 (전체 텍스트)
   - `embedding` (vector): 1536차원 벡터 임베딩
   - `embedding_updated_at` (datetime): 임베딩 업데이트 시간
   - `sort_order` (integer): 정렬 순서

6. **Clause**: 조의 항/호
   - `article_id` (references): 소속 조
   - `type` (string): 유형 (paragraph, item, subitem)
   - `number` (string): 항/호 번호 (예: "①", "1.", "가.")
   - `content` (text): 내용
   - `sort_order` (integer): 정렬 순서

7. **Attachment**: 별표/별지
   - `regulation_id` (references): 소속 규정
   - `type` (string): 유형 (table, form, appendix)
   - `number` (string): 별표/별지 번호
   - `title` (string): 제목
   - `content` (text): 내용
   - `file_path` (string): 파일 경로 (이미지/PDF인 경우)

8. **RegulationHistory**: 규정 개정 이력
   - `regulation_id` (references): 규정 ID
   - `version` (integer): 버전 번호
   - `amendment_date` (date): 개정 일자
   - `amendment_reason` (text): 개정 사유
   - `amended_by` (string): 개정 기관/부서

**검색 및 대화 모델:**

9. **Conversation**: 대화 세션
   - `session_id` (string, unique): 브라우저 세션 ID (UUID)
   - `title` (string): 대화 제목 (첫 질문 기반 자동 생성)
   - `created_at` (datetime): 생성 시간
   - `expires_at` (datetime): 만료 시간 (7일 후)
   - `last_message_at` (datetime): 마지막 메시지 시간
   - `message_count` (integer): 메시지 수

10. **Message**: 질문/답변 메시지
    - `conversation_id` (references): 대화 세션
    - `role` (string): 역할 ('user' 또는 'assistant')
    - `content` (text): 메시지 내용
    - `sources` (json): 참조된 규정 조항 정보
    - `processing_time` (float): AI 처리 시간 (초)
    - `tokens_used` (integer): 사용된 토큰 수
    - `created_at` (datetime): 생성 시간

**시스템 설정 모델:**

11. **AiSetting**: AI 설정
    - `provider` (string): AI 제공업체 (openai, anthropic, google)
    - `model_name` (string): 모델 명
    - `api_key_encrypted` (text): 암호화된 API 키
    - `monthly_budget` (decimal): 월 예산 한도
    - `current_usage` (decimal): 현재 월 사용량
    - `is_active` (boolean): 활성 상태
    - `environment` (string): 환경 (development, production)

12. **SystemLog**: 시스템 로그
    - `action` (string): 수행 작업
    - `user_id` (references): 수행 사용자
    - `target_type` (string): 대상 모델
    - `target_id` (integer): 대상 ID
    - `details` (json): 상세 정보
    - `ip_address` (string): IP 주소
    - `created_at` (datetime): 실행 시간

## 4. 핵심 기능 요구사항

### 4.1. 관리자 기능

**인증 및 권한:**

- Rails 내장 `has_secure_password` 사용
- 관리자만 규정 CRUD 및 시스템 설정 접근

**규정 관리:**

- 웹 인터페이스를 통한 규정 CRUD
- 편/장/규정/조/항/호 계층 구조 관리
- 별지/별표 첨부 파일 관리

**임베딩 동기화:**

- 관리자가 `rake embeddings:sync` 명령어로 수동 실행
- 웹 인터페이스에서 동기화 버튼 제공
- 동기화 진행 상황 및 결과 표시

**AI 설정 관리:**

- API 키 설정 (OpenAI/Anthropic/Google)
- 로컬 LLM 설정 (Ollama, LM Studio, GPT4All 등)
- 모델 선택 및 파라미터 조정
- 월 예산 한도 설정
- 환경별 모델 구성 (개발/배포)
- 다중 AI 제공업체 지원

### 4.2. 사용자 기능

**검색 인터페이스:**

- 대화형 채팅 인터페이스
- 자연어 질문 입력
- 실시간 답변 표시 (Hotwire Turbo)

**검색 결과:**

- AI 답변과 참조 규정 분리 표시
- 관련 규정 조항 링크 제공
- 대화 히스토리 유지 (최근 5-10개 메시지)

**익명 사용자 지원:**

- 로그인 없이 검색 가능
- 브라우저 세션 기반 대화 연속성
- 7일 후 자동 세션 만료

### 4.3. 데이터 변환 및 임포트 전략

**원본 데이터 특성 분석:**

- **파일 규모**: 74,707줄의 대용량 텍스트 파일
- **복합 구조**: 규정 본문, 별표, 서식, 인덱스가 혼재
- **비일관성**: 폐지 규정, 번호 체계 예외, 형식 변화 존재
- **한글 처리**: 조항 번호의 한글 표기 (제1조, ①, 가. 등)

**단계별 데이터 변환 프로세스:**

#### 1단계: 텍스트 전처리 및 구조 분석

**파일 분할 및 정제:**
```ruby
# lib/tasks/data_import.rake
task :preprocess_regulations => :environment do
  RegulationParser.new.preprocess(file_path)
end
```

**구조 식별 패턴:**
- **편 식별**: "제X편" 패턴 인식
- **장 식별**: "제X장" 패턴 인식  
- **규정 식별**: "X-Y-Z" 코드 패턴 인식
- **조 식별**: "제X조" 패턴 인식
- **항/호 식별**: "①", "1.", "가." 패턴 인식
- **폐지 표시**: "【폐지】" 마크 처리

#### 2단계: AI 기반 구조화 파싱

**파싱 정확도 향상 방안:**
```ruby
class RegulationAiParser
  def parse_regulation_block(text_block)
    # GPT-4 또는 Claude를 사용한 구조 분석
    # 프롬프트 엔지니어링으로 95% 이상 정확도 달성
  end
end
```

**파싱 규칙 정의:**
- **제목 추출**: 규정명과 조항 제목 자동 추출
- **내용 분리**: 조 본문과 항/호 내용 분리
- **참조 관계**: 다른 규정 참조 관계 식별
- **별표 연결**: 본문과 별표/서식 연결 관계 파악

#### 3단계: 구조화된 JSON 생성

**중간 데이터 형식:**
```json
{
  "editions": [
    {
      "number": 1,
      "title": "학교법인",
      "chapters": [
        {
          "number": 1,
          "title": "법인",
          "regulations": [
            {
              "code": "1-1-1",
              "title": "정관",
              "status": "active",
              "articles": [
                {
                  "number": "제1조",
                  "title": "목적",
                  "content": "조 전체 내용",
                  "clauses": [
                    {
                      "number": "①",
                      "content": "항 내용"
                    }
                  ]
                }
              ]
            }
          ]
        }
      ]
    }
  ]
}
```

#### 4단계: 데이터 검증 및 품질 관리

**자동 검증 규칙:**
- **계층 구조 무결성**: 상위-하위 관계 검증
- **번호 체계 일관성**: 규정 코드 중복/누락 검사
- **참조 관계 유효성**: 존재하지 않는 규정 참조 검사
- **필수 필드 완성도**: 제목, 내용 등 필수 정보 검증

**수동 검토 인터페이스:**
- **파싱 결과 미리보기**: 변환된 구조 시각화
- **오류 표시 및 수정**: 파싱 실패 부분 하이라이트
- **일괄 수정 도구**: 유사한 오류 패턴 일괄 처리
- **변환 전후 비교**: 원본과 변환 결과 비교 뷰

#### 5단계: 데이터베이스 임포트

**배치 처리 최적화:**
```ruby
class RegulationImporter
  def import_batch(json_data, batch_size: 1000)
    # 트랜잭션 기반 배치 처리
    # 메모리 효율적인 대용량 데이터 처리
  end
end
```

**관계 설정 및 무결성:**
- **외래키 제약조건**: 데이터 무결성 보장
- **인덱스 최적화**: 검색 성능 향상
- **중복 데이터 처리**: 동일 규정 중복 입력 방지

#### 6단계: 임베딩 생성

**벡터 임베딩 전략:**
- **조 단위 임베딩**: 각 조별로 독립적인 임베딩 생성
- **컨텍스트 보강**: 규정 제목, 장/편 정보 포함
- **배치 처리**: API 호출 최적화로 비용 절감
- **진행률 추적**: 임베딩 생성 진행 상황 모니터링

**임베딩 품질 관리:**
```ruby
class EmbeddingManager
  def generate_embeddings_batch(articles, batch_size: 100)
    # OpenAI text-embedding-3-small 사용
    # 배치 처리로 API 비용 최적화
    # 실패한 임베딩 재시도 로직
  end
end
```

### 4.4. 데이터 품질 관리 및 오류 처리

**예상 파싱 문제점과 해결 방안:**

**1. 번호 체계 불일치 문제:**
- **문제**: "3-1-65A", "3-1-65-1" 등 예외적인 번호 체계
- **해결**: 정규표현식 패턴 확장 및 예외 규칙 정의
- **검증**: 중복 번호 체크 및 순서 정렬 검증

**2. 폐지 규정 처리:**
- **문제**: 【폐지】 표시된 규정의 이력 관리
- **해결**: `status` 필드로 상태 관리, `abolished_at` 날짜 기록
- **참조 유지**: 다른 규정에서 폐지된 규정 참조 시 경고 표시

**3. 복합 문서 구조:**
- **문제**: 규정 본문, 별표, 서식이 혼재된 구조
- **해결**: 문서 타입별 분리 파싱 및 연결 관계 매핑
- **별표 처리**: 표 형태 데이터의 구조화된 저장

**4. 한글 조항 번호 처리:**
- **문제**: "제1조의2", "①", "가." 등 다양한 번호 형식
- **해결**: 한글 번호 체계 정규화 함수 구현
- **정렬**: 자연어 정렬 알고리즘 적용

**실시간 검증 시스템:**

```ruby
class RegulationValidator
  def validate_structure(regulation_data)
    errors = []
    
    # 필수 필드 검증
    errors << "제목 누락" if regulation_data[:title].blank?
    
    # 번호 체계 검증
    errors << "규정 코드 형식 오류" unless valid_code_format?(regulation_data[:code])
    
    # 계층 관계 검증
    errors << "상위 장 참조 오류" unless chapter_exists?(regulation_data[:chapter_id])
    
    errors
  end
end
```

**데이터 품질 메트릭:**
- **파싱 성공률**: 자동 파싱된 규정 비율
- **수동 수정률**: 인간 검토가 필요한 항목 비율  
- **참조 무결성**: 유효하지 않은 규정 참조 건수
- **중복 탐지**: 동일 내용의 중복 규정 탐지

## 5. UI/UX 요구사항

### 5.1. 관리자 인터페이스

**대시보드:**

- 시스템 상태 및 통계 제공
- 최근 규정 변경 사항 표시
- 임베딩 동기화 상태 확인

**규정 관리:**

- 직관적인 CRUD 인터페이스
- 계층 구조 트리 뷰
- 검색 및 필터링 기능

**AI 설정:**

- API 키 관리 (마스킹 처리)
- 모델 선택 및 파라미터 설정
- 월 예산 한도 설정

### 5.2. 사용자 인터페이스

**검색 페이지:**

- 간단하고 직관적인 검색 인터페이스
- 대화형 채팅 UI
- 실시간 답변 표시

**결과 표시:**

- AI 답변과 참조 문서 명확히 구분
- 관련 규정 조항 링크 제공
- 대화 히스토리 유지

**반응형 디자인:**

- 모바일/태블릿/데스크톱 지원
- 터치 친화적 인터페이스
- 기본 접근성 지원

### 5.3. 대학 CI 적용

- 대학 로고 및 색상 체계 적용
- Tailwind CSS 커스텀 컬러 설정
- 공식 서체 적용 (가능한 경우)

## 6. 성능 및 확장성 요구사항

### 6.1. 성능 목표

- **검색 응답 시간**: 3-5초 이내
- **동시 사용자**: 최대 50명 지원
- **임베딩 동기화**: 전체 동기화 20분 이내
- **시스템 가용성**: 99% 이상

### 6.2. 데이터 변환 및 처리 요구사항

- **초기 데이터 변환**: 74,707줄 텍스트 파일 처리 능력
- **구조 분석 정확도**: AI 파싱 95% 이상 정확도 목표
- **중간 파일 검증**: JSON 구조 무결성 검증 기능
- **점진적 임포트**: 대용량 데이터의 배치 처리 지원

### 6.3. 확장성 고려사항

- **다중 대학 지원**: 향후 여러 대학 규정 통합 관리
- **API 확장**: RESTful API 제공 가능
- **모바일 앱 지원**: API 기반 모바일 앱 개발 가능
- **데이터 형식 확장**: 다양한 규정 문서 형식 지원

## 7. 보안 요구사항

### 7.1. 데이터 보안

- **API 키 관리**: Rails credentials를 통한 안전한 저장
- **데이터베이스 접근**: 최소 권한 원칙 적용
- **로그 관리**: 민감한 정보 로그 배제

### 7.2. 접근 제어

- **관리자 인증**: 강력한 패스워드 정책
- **세션 관리**: 안전한 세션 쿠키 설정
- **CSRF 보호**: Rails 내장 보안 기능 활용

## 8. 배포 및 운영

### 8.1. 배포 환경

- **호스팅**: Render 무료 티어 활용
- **데이터베이스**: PostgreSQL with pgvector
- **예상 비용**: 월 $2-5 (AI API 사용량)
- **Cold Start 방지**: 정기적인 ping으로 서비스 활성 상태 유지

### 8.2. 운영 관리

- **백업**: 호스팅 플랫폼 자동 백업
- **모니터링**: 기본 로그 및 메트릭 확인
- **업데이트**: Rails 보안 패치 적용

## 9. 성공 지표

### 9.1. 기능적 성공 지표

- **규정 관리**: 관리자가 웹에서 모든 규정을 관리할 수 있음
- **검색 정확도**: 일반적인 질문에 대해 90% 이상 관련성 있는 답변
- **시스템 안정성**: 지속적인 서비스 제공 (99% 가용성)

### 9.2. 사용자 만족도

- **관리 편의성**: 기존 대비 규정 관리 시간 50% 단축
- **검색 편의성**: 자연어 질문으로 원하는 정보 쉽게 찾기
- **시스템 신뢰성**: 정확하고 일관된 답변 제공

## 10. 결론

본 PRD는 대학 규정 관리 및 AI 검색 시스템 개발을 위한 핵심 요구사항을 정의합니다.

**핵심 목표**:

1. **관리 효율성**: 웹 기반 직관적인 규정 관리
2. **검색 혁신**: AI 기반 자연어 검색으로 정보 접근성 향상
3. **시스템 안정성**: 확장 가능하고 유지보수하기 쉬운 아키텍처

이 시스템을 통해 대학 구성원들은 복잡한 규정 정보를 쉽고 빠르게 찾을 수 있으며, 관리자는 효율적으로 규정을 관리할 수 있습니다.

---

## 추가 질문사항

### 프로젝트 구현을 위한 필수 결정사항

AI 구현을 위해 다음 사항들을 명확히 해주시기 바랍니다:

#### 1. 기술적 설정

**AI API 선택:**
- 로컬 개발: OpenAI, Anthropic, Google, 또는 로컬 LLM (Ollama, LM Studio, GPT4All 등) 중 선호하는 옵션이 있나요?
- 배포 환경: OpenAI, Anthropic, Google 중 선호하는 제공업체가 있나요?
- 임베딩 모델: OpenAI text-embedding-3-small vs text-embedding-3-large 중 선택?

**예산 및 운영:**
- 월 AI API 사용 예산 한도는 어느 정도로 설정하시겠습니까?
- 동시 사용자 수 예상치는? (성능 최적화 기준)

#### 2. 데이터 변환 전략

**원본 데이터 처리:**
- regulations9-340-20250702.txt 파일의 인코딩 형식은? (UTF-8, EUC-KR 등)
- AI 파싱 실패 시 수동 검토 프로세스를 어떻게 진행하시겠습니까?
- 폐지된 규정들을 시스템에서 어떻게 표시하시겠습니까? (완전 숨김, 회색 표시, 별도 섹션)

**데이터 검증:**
- 파싱 정확도 임계치를 몇 %로 설정하시겠습니까? (95% 이상 권장)
- 중간 JSON 파일을 Git으로 버전 관리하시겠습니까?

#### 3. 사용자 인터페이스

**대학 CI 적용:**
- CI/deu.png 파일이 공식 로고인가요?
- 대학 공식 색상 코드(헥스 코드)를 제공해주실 수 있나요?
- 특정 서체를 사용해야 하나요? (나눔고딕, 맑은고딕 등)

**관리자 설정:**
- 초기 관리자 이메일과 임시 비밀번호를 어떻게 설정하시겠습니까?
- 다중 관리자 계정이 필요한가요?

#### 4. 배포 및 운영

**호스팅 환경:**
- 사용할 도메인이 있나요? (예: regulations.deu.ac.kr)
- PostgreSQL과 Redis 버전 선호사항이 있나요?
- SSL 인증서 설정 방법은? (Let's Encrypt 자동 설정 vs 수동 설정)

**데이터 보안:**
- 사용자 질문 로그를 얼마나 보관하시겠습니까? (30일, 90일, 1년)
- 관리자 접근을 특정 IP로 제한하시겠습니까?

#### 5. 시스템 기능

**검색 및 답변:**
- AI 답변 언어를 한국어로 고정하시겠습니까, 아니면 질문 언어에 따라 자동 선택?
- 검색 결과에서 폐지된 규정도 포함시키시겠습니까?
- 답변에 "확신도" 점수를 표시하시겠습니까?

**알림 및 모니터링:**
- 시스템 오류 알림을 받을 이메일 주소는?
- 월간 사용량 리포트가 필요하신가요?

#### 6. 향후 확장성

**다중 대학 지원:**
- 향후 다른 대학 규정도 통합 관리할 계획이 있나요?
- 대학별 별도 도메인이 필요한가요?

**모바일 지원:**
- 별도 모바일 앱 개발 계획이 있나요?
- PWA(Progressive Web App) 형태로 모바일 지원하시겠습니까?

---

### 우선순위 결정사항

**즉시 결정 필요 (개발 시작 전):**
1. AI 제공업체 선택 (OpenAI/Anthropic/Google)
2. 예산 한도 설정
3. 관리자 계정 정보
4. 대학 CI 자료 (로고, 색상)

**개발 초기 단계에서 결정:**
1. 도메인 설정
2. 데이터 변환 정확도 기준
3. 폐지 규정 표시 방법
4. 보안 정책

**개발 완료 후 결정:**
1. 운영 정책 (로그 보관 기간 등)
2. 확장 계획
3. 사용자 교육 방안

이 정보들을 제공해주시면 보다 구체적이고 실행 가능한 개발 계획을 수립할 수 있습니다.

---

## RAG 시스템 구현 및 성능 최적화

### 4.5. RAG 시스템 구현 상세

**벡터 검색 최적화:**

**임베딩 전략:**
- **모델 선택**: OpenAI text-embedding-3-small (1536차원)
- **텍스트 전처리**: 조 제목 + 내용 + 상위 맥락 (규정/장/편 정보)
- **청킹 전략**: 조 단위 분할 (평균 200-500 토큰)
- **메타데이터 포함**: 규정 코드, 제정/개정 일자, 소관 부서

**검색 정확도 향상:**

```ruby
class RegulationSearchService
  def search(query, limit: 10, similarity_threshold: 0.7)
    # 1. 쿼리 임베딩 생성
    query_embedding = generate_embedding(query)
    
    # 2. 벡터 유사도 검색
    similar_articles = Article.joins(:regulation, :chapter, :edition)
                             .where("embedding <=> ? < ?", query_embedding, 1 - similarity_threshold)
                             .order(Arel.sql("embedding <=> '#{query_embedding}'"))
                             .limit(limit)
                             .includes(:regulation, :clauses)
    
    # 3. 메타데이터 기반 리랭킹
    rerank_results(similar_articles, query)
  end
  
  private
  
  def rerank_results(articles, query)
    # 규정 활성 상태, 최신성, 부서 관련성 등을 고려한 재정렬
  end
end
```

**컨텍스트 구성:**
- **상위 맥락**: 검색된 조의 소속 규정/장/편 정보 포함
- **관련 조항**: 동일 규정 내 관련 조항 자동 포함
- **참조 관계**: 다른 규정 참조 시 해당 규정 정보 추가
- **이력 정보**: 개정 이력 및 폐지 여부 명시

**답변 생성 최적화:**

```ruby
class AiResponseGenerator
  def generate_response(query, context_articles)
    system_prompt = build_system_prompt
    context = build_context(context_articles)
    
    response = ai_client.chat(
      model: current_model,
      messages: [
        { role: "system", content: system_prompt },
        { role: "user", content: "#{context}\n\n질문: #{query}" }
      ],
      temperature: 0.1,
      max_tokens: 1500
    )
    
    {
      answer: response.dig("choices", 0, "message", "content"),
      sources: extract_sources(context_articles),
      confidence: calculate_confidence(context_articles),
      tokens_used: response.dig("usage", "total_tokens")
    }
  end
  
  private
  
  def build_system_prompt
    "당신은 동의대학교 규정 전문가입니다. 제공된 규정 조항을 바탕으로 정확하고 명확한 답변을 제공하세요.
     
     답변 원칙:
     1. 제공된 규정 조항만을 근거로 답변
     2. 불확실한 경우 '관련 조항을 찾을 수 없음' 명시
     3. 규정 코드와 조항 번호 정확히 인용
     4. 폐지된 규정의 경우 명확히 안내"
  end
end
```

### 4.6. 성능 최적화 및 확장성

**데이터베이스 최적화:**

**인덱스 전략:**
```sql
-- 벡터 검색 최적화
CREATE INDEX idx_articles_embedding ON articles USING ivfflat (embedding vector_cosine_ops);

-- 텍스트 검색 최적화  
CREATE INDEX idx_articles_content_gin ON articles USING gin(to_tsvector('korean', content));

-- 계층 구조 검색 최적화
CREATE INDEX idx_regulations_code ON regulations(code);
CREATE INDEX idx_articles_regulation_number ON articles(regulation_id, sort_order);

-- 대화 검색 최적화
CREATE INDEX idx_conversations_session_expires ON conversations(session_id, expires_at);
CREATE INDEX idx_messages_conversation_created ON messages(conversation_id, created_at);
```

**캐싱 전략:**
- **임베딩 캐싱**: 자주 검색되는 쿼리의 임베딩 결과 캐시
- **검색 결과 캐싱**: 동일 질문에 대한 답변 30분 캐싱
- **규정 메타데이터**: 규정 구조 정보 Redis 캐싱
- **AI 응답**: 완전히 동일한 질문의 AI 응답 12시간 캐싱

**배치 처리 최적화:**

```ruby
class EmbeddingBatchProcessor
  def process_pending_embeddings
    Article.where(embedding: nil)
           .or(Article.where("embedding_updated_at < updated_at"))
           .find_in_batches(batch_size: 100) do |batch|
      
      embeddings = generate_embeddings_batch(batch.map(&:content))
      
      batch.each_with_index do |article, index|
        article.update!(
          embedding: embeddings[index],
          embedding_updated_at: Time.current
        )
      end
    end
  end
end
```

**모니터링 및 알림:**
- **API 사용량 추적**: 실시간 토큰 사용량 모니터링
- **검색 성능 추적**: 평균 응답 시간 및 정확도 메트릭
- **오류 알림**: 임베딩 생성 실패, API 한도 초과 알림
- **데이터 품질 알림**: 파싱 오류율 임계치 초과 시 알림

이 정보들을 제공해주시면 보다 구체적이고 실행 가능한 개발 계획을 수립할 수 있습니다.