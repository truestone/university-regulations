# 🚀 규정 관리 시스템 배포 가이드

## 📋 목차
- [빠른 시작](#빠른-시작)
- [개발 환경](#개발-환경)
- [프로덕션 배포](#프로덕션-배포)
- [백업 및 복원](#백업-및-복원)
- [GitHub Actions 자동 배포](#github-actions-자동-배포)

## 🚀 빠른 시작

### 1. 저장소 클론
```bash
git clone https://github.com/yourusername/regulations-system.git
cd regulations-system
```

### 2. 개발 환경 실행
```bash
# 스크립트 실행 권한 부여
chmod +x scripts/*.sh

# 개발 환경 배포
./scripts/deploy.sh development
```

### 3. 서비스 확인
- 웹 인터페이스: http://localhost:3000
- PostgreSQL: localhost:5432
- Redis: localhost:6379

## 🔧 개발 환경

### 로컬 빌드 및 실행
```bash
# Docker 이미지 빌드
docker-compose -f docker-compose.single.yml build

# 서비스 시작
docker-compose -f docker-compose.single.yml up -d

# 로그 확인
docker-compose -f docker-compose.single.yml logs -f
```

### 개발 도구
```bash
# Rails 콘솔 접속
docker exec -it regulations-app-1 rails console

# 데이터베이스 접속
docker exec -it regulations-app-1 psql -U postgres regulations_development

# 컨테이너 내부 접속
docker exec -it regulations-app-1 /bin/sh
```

## 🌐 프로덕션 배포

### 1. 환경 설정
```bash
# 프로덕션 환경변수 설정
cp .env.example .env.production
# .env.production 파일을 편집하여 실제 값 입력
```

### 2. 프로덕션 배포
```bash
# 프로덕션 환경 배포
./scripts/deploy.sh production

# 또는 특정 이미지로 배포
./scripts/deploy.sh production ghcr.io/yourusername/regulations-system:v1.0.0
```

### 3. 도메인 설정 (선택사항)
```bash
# nginx 프록시 설정 예시
server {
    listen 80;
    server_name your-domain.com;
    
    location / {
        proxy_pass http://localhost:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

## 💾 백업 및 복원

### 백업 생성
```bash
# 전체 시스템 백업
./scripts/backup.sh

# 백업 파일 확인
ls -la backups/
```

### 복원 실행
```bash
# 특정 백업으로 복원
./scripts/restore.sh backups/20250107_143000

# 복원 후 서비스 확인
curl http://localhost:3000/up
```

## 🐙 GitHub Actions 자동 배포

### 1. GitHub Secrets 설정
Repository Settings > Secrets and variables > Actions에서 다음 설정:

```
OPENAI_API_KEY: your_openai_api_key
ANTHROPIC_API_KEY: your_anthropic_api_key
SECRET_KEY_BASE: your_secret_key_base
```

### 2. 자동 빌드 트리거
```bash
# main 브랜치에 푸시하면 자동 빌드
git add .
git commit -m "Deploy to production"
git push origin main

# 태그 생성으로 릴리즈 빌드
git tag v1.0.0
git push origin v1.0.0
```

### 3. GitHub Container Registry에서 배포
```bash
# 자동 빌드된 이미지로 배포
./scripts/deploy.sh github
```

## 🔍 트러블슈팅

### 서비스가 시작되지 않는 경우
```bash
# 컨테이너 상태 확인
docker ps -a

# 로그 확인
docker logs regulations-app-1

# 서비스 재시작
docker-compose -f docker-compose.single.yml restart
```

### 데이터베이스 연결 오류
```bash
# PostgreSQL 서비스 확인
docker exec regulations-app-1 supervisorctl status postgresql

# 데이터베이스 재시작
docker exec regulations-app-1 supervisorctl restart postgresql
```

### 포트 충돌 해결
```bash
# 사용 중인 포트 확인
lsof -i :3000

# 다른 포트로 실행
PORT=8080 docker-compose -f docker-compose.single.yml up -d
```

## 📊 모니터링

### 시스템 상태 확인
```bash
# 컨테이너 리소스 사용량
docker stats regulations-app-1

# 볼륨 사용량
docker system df -v

# 서비스 헬스체크
curl http://localhost:3000/up
```

### 로그 모니터링
```bash
# 실시간 로그 확인
docker logs -f regulations-app-1

# 특정 서비스 로그
docker exec regulations-app-1 tail -f /var/log/supervisor/rails.log
docker exec regulations-app-1 tail -f /var/log/supervisor/postgresql.log
```

이 가이드를 따라하면 완전한 백업, 배포, 복원이 가능합니다! 🎉