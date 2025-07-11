# 규정집 파서 설계 문서

## 1. 개요

### 1.1 목적
- 74,706줄의 동의대학교 규정집 텍스트 파일을 구조화된 데이터로 변환
- Edition(편) → Chapter(장) → Regulation(규정) → Article(조문) → Clause(항) 계층 구조 파싱
- 메모리 효율적인 스트리밍 파싱으로 대용량 파일 처리

### 1.2 입력 파일 분석
- **파일명**: regulations9-340-20250702.txt
- **총 라인 수**: 74,706줄
- **인코딩**: UTF-8
- **구조**: 계층적 규정 문서

## 2. 파일 포맷 명세

### 2.1 계층 구조 패턴

#### Edition (편) 패턴
```
제1편  학교법인
제2편  학  칙
제3편  행  정
```
- 정규식: `^제(\d+)편\s+(.+)$`

#### Chapter (장) 패턴
```
제1장  일반 행정
제2장  교  무
```
- 정규식: `^제(\d+)장\s+(.+)$`

#### Regulation (규정) 패턴
```
직제규정	3-1-1
사무분장규정	3-1-2
교원인사규정	3-1-5
```
- 정규식: `^(.+)\s+(\d+-\d+-\d+)$`

#### Article (조문) 패턴
```
제1조 (목적) 이 규정은...
제18조 (승진업적평가점수) ① 승진심사대상자가...
```
- 정규식: `^제(\d+)조\s*\(([^)]+)\)\s*(.*)$`

#### Clause (항) 패턴
```
① 제2의 전공(복수전공 및 연계·융합전공)은...
② 무기정학 중인 학생의 징계 해제는...
```
- 정규식: `^[①②③④⑤⑥⑦⑧⑨⑩]\s*(.+)$`

### 2.2 특수 패턴

#### 부칙 패턴
```
부  칙
부    칙
```

#### 별표/별지 패턴
```
<별표 1>
[별지 제1호 서식]
```

#### 날짜 패턴
```
2019년  2월  1일
20   년    월    일
```

## 3. 상태 머신 설계

### 3.1 파서 상태 정의

```ruby
module ParserState
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
```

### 3.2 상태 전이도

```
INITIAL
  ├─ "제N편" → EDITION
  ├─ "차례" → SKIP
  └─ 기타 → SKIP

EDITION
  ├─ "제N장" → CHAPTER
  ├─ "제N편" → EDITION
  └─ 규정명 → REGULATION

CHAPTER
  ├─ "제N장" → CHAPTER
  ├─ "제N편" → EDITION
  └─ 규정명 → REGULATION

REGULATION
  ├─ "제N조" → ARTICLE
  ├─ "부칙" → APPENDIX
  ├─ "제N장" → CHAPTER
  ├─ "제N편" → EDITION
  └─ 규정명 → REGULATION

ARTICLE
  ├─ "①②③..." → CLAUSE
  ├─ "제N조" → ARTICLE
  ├─ "부칙" → APPENDIX
  └─ 기타 → REGULATION

CLAUSE
  ├─ "①②③..." → CLAUSE
  ├─ "제N조" → ARTICLE
  └─ 기타 → REGULATION
```

### 3.3 에러 상태 처리

- **UNKNOWN_PATTERN**: 인식되지 않는 패턴
- **INVALID_HIERARCHY**: 잘못된 계층 구조
- **MISSING_PARENT**: 부모 요소 없음
- **DUPLICATE_CODE**: 중복된 규정 코드

## 4. 메모리 최적화 전략

### 4.1 스트리밍 파싱
- 전체 파일을 메모리에 로드하지 않고 라인별 처리
- 현재 상태와 컨텍스트만 메모리에 유지

### 4.2 배치 처리
- 1000개 레코드 단위로 데이터베이스 삽입
- 트랜잭션 크기 제한으로 메모리 사용량 제어

### 4.3 가비지 컬렉션 최적화
- 임시 객체 생성 최소화
- String freeze로 메모리 중복 방지

## 5. 벤치마킹 지표

### 5.1 성능 메트릭
- **처리 속도**: 라인/초
- **메모리 사용량**: Peak RSS
- **파싱 정확도**: 성공/실패 비율
- **에러 복구율**: 에러 후 정상 파싱 재개 비율

### 5.2 측정 도구
```ruby
class ParserBenchmark
  def initialize
    @start_time = Time.now
    @start_memory = memory_usage
    @processed_lines = 0
    @errors = []
  end

  def record_line
    @processed_lines += 1
  end

  def record_error(error)
    @errors << error
  end

  def report
    {
      duration: Time.now - @start_time,
      memory_peak: memory_usage - @start_memory,
      lines_per_second: @processed_lines / (Time.now - @start_time),
      error_rate: @errors.size.to_f / @processed_lines,
      total_lines: @processed_lines
    }
  end

  private

  def memory_usage
    `ps -o rss= -p #{Process.pid}`.to_i * 1024
  end
end
```

## 6. 예외 처리 전략

### 6.1 복구 가능한 에러
- 인식되지 않는 라인 → SKIP 상태로 전환
- 잘못된 번호 순서 → 경고 로그 후 계속 진행
- 빈 라인 → 무시하고 다음 라인 처리

### 6.2 치명적 에러
- 파일 읽기 실패 → 즉시 중단
- 메모리 부족 → 배치 크기 축소 후 재시도
- 데이터베이스 연결 실패 → 재연결 시도

## 7. 출력 데이터 구조

### 7.1 JSON 스키마
```json
{
  "editions": [
    {
      "number": 1,
      "title": "학교법인",
      "chapters": [
        {
          "number": 1,
          "title": "일반 행정",
          "regulations": [
            {
              "code": "3-1-1",
              "title": "직제규정",
              "articles": [
                {
                  "number": 1,
                  "title": "목적",
                  "content": "이 규정은...",
                  "clauses": [
                    {
                      "number": 1,
                      "content": "제2의 전공은...",
                      "type": "paragraph"
                    }
                  ]
                }
              ]
            }
          ]
        }
      ]
    }
  ],
  "metadata": {
    "total_editions": 6,
    "total_regulations": 340,
    "parsing_errors": [],
    "processed_at": "2025-01-11T10:20:00Z"
  }
}
```

## 8. 구현 계획

### 8.1 Phase 1: 기본 파서 구현
- 상태 머신 클래스 작성
- 정규식 패턴 정의
- 기본 파싱 로직 구현

### 8.2 Phase 2: 최적화 및 에러 처리
- 메모리 사용량 최적화
- 에러 복구 로직 추가
- 벤치마킹 도구 통합

### 8.3 Phase 3: 통합 테스트
- 전체 파일 파싱 테스트
- 성능 벤치마크 실행
- 데이터 검증 및 품질 확인

## 9. 테스트 전략

### 9.1 단위 테스트
- 각 정규식 패턴별 테스트
- 상태 전이 로직 테스트
- 에러 처리 시나리오 테스트

### 9.2 통합 테스트
- 소형 샘플 파일 (100줄) 파싱
- 중형 샘플 파일 (1000줄) 파싱
- 전체 파일 파싱 및 검증

### 9.3 성능 테스트
- 메모리 사용량 프로파일링
- 처리 속도 벤치마크
- 대용량 파일 스트레스 테스트