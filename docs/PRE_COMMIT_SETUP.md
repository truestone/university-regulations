# 🔧 Pre-commit 훅 설정 가이드

## 📋 개요
이 프로젝트는 코드 품질 유지를 위해 pre-commit 훅을 사용합니다. 커밋 전에 자동으로 코드 린트, 포맷팅, 검사를 수행합니다.

## 🚀 설치 방법

### 1. Pre-commit 설치
```bash
# macOS (Homebrew)
brew install pre-commit

# Ubuntu/Debian
sudo apt install pre-commit

# pip 사용
pip install pre-commit
```

### 2. 프로젝트에서 pre-commit 활성화
```bash
# 저장소 클론 후
cd regulations-system

# pre-commit 훅 설치
pre-commit install

# 모든 파일에 대해 한 번 실행 (선택사항)
pre-commit run --all-files
```

## 🔍 포함된 검사 항목

### 1. 일반 검사
- **trailing-whitespace**: 줄 끝 공백 제거
- **end-of-file-fixer**: 파일 끝 개행 문자 확인
- **check-yaml**: YAML 파일 문법 검사
- **check-json**: JSON 파일 문법 검사
- **check-added-large-files**: 대용량 파일 추가 방지
- **check-merge-conflict**: 머지 충돌 마커 검사

### 2. Ruby/Rails 검사
- **RuboCop**: Ruby 코드 스타일 및 품질 검사
- **RuboCop Rails**: Rails 특화 규칙
- **RuboCop RSpec**: RSpec 테스트 코드 규칙

### 3. 기타 검사
- **yamllint**: YAML 파일 린트
- **shellcheck**: Shell 스크립트 검사

## ⚙️ 설정 파일

### `.pre-commit-config.yaml`
Pre-commit 훅 설정 파일

### `.rubocop.yml`
RuboCop 규칙 설정:
- 줄 길이: 120자
- 메서드 길이: 15줄
- 클래스 길이: 100줄
- 문자열: 단일 따옴표 사용
- 트레일링 콤마: 일관성 유지

## 🔧 사용법

### 자동 실행
```bash
# 커밋 시 자동으로 실행됨
git commit -m "Your commit message"
```

### 수동 실행
```bash
# 모든 파일 검사
pre-commit run --all-files

# 특정 훅만 실행
pre-commit run rubocop
pre-commit run shellcheck

# 스테이징된 파일만 검사
pre-commit run
```

### RuboCop 개별 실행
```bash
# Docker 환경에서 RuboCop 실행
docker exec regulations-app-1 bundle exec rubocop

# 자동 수정
docker exec regulations-app-1 bundle exec rubocop --auto-correct

# 특정 파일만 검사
docker exec regulations-app-1 bundle exec rubocop app/models/user.rb
```

## 🚫 훅 우회 (비상시만 사용)
```bash
# 모든 훅 우회
git commit --no-verify -m "Emergency commit"

# 특정 훅만 건너뛰기
SKIP=rubocop git commit -m "Skip rubocop"
```

## 🔄 훅 업데이트
```bash
# 훅 설정 업데이트
pre-commit autoupdate

# 훅 재설치
pre-commit uninstall
pre-commit install
```

## 📊 CI에서 검증
GitHub Actions에서도 동일한 검사를 수행하여 일관성을 보장합니다:

```yaml
- name: Run pre-commit
  uses: pre-commit/action@v3.0.0
```

## 🎯 권장 워크플로우
1. 코드 작성
2. `git add .`
3. `git commit -m "message"` (자동으로 pre-commit 실행)
4. 오류 발생 시 수정 후 다시 커밋
5. `git push`

이렇게 설정하면 코드 품질이 자동으로 유지됩니다! 🎉