#!/bin/bash
# 규정 관리 시스템 복원 스크립트

set -e

if [ -z "$1" ]; then
    echo "사용법: $0 <백업_디렉토리>"
    echo "예시: $0 backups/20250107_143000"
    exit 1
fi

BACKUP_DIR="$1"

if [ ! -d "$BACKUP_DIR" ]; then
    echo "❌ 백업 디렉토리를 찾을 수 없습니다: $BACKUP_DIR"
    exit 1
fi

echo "🔄 복원 시작: $BACKUP_DIR"

# 1. 기존 컨테이너 중지
echo "⏹️ 기존 컨테이너 중지 중..."
docker-compose -f docker-compose.single.yml down

# 2. 볼륨 복원
echo "💾 PostgreSQL 볼륨 복원 중..."
docker volume create regulations_postgres_data
docker run --rm -v regulations_postgres_data:/data -v "$(pwd)/$BACKUP_DIR":/backup alpine tar xzf /backup/postgres-volume.tar.gz -C /data

echo "🔄 Redis 볼륨 복원 중..."
docker volume create regulations_redis_data
docker run --rm -v regulations_redis_data:/data -v "$(pwd)/$BACKUP_DIR":/backup alpine tar xzf /backup/redis-volume.tar.gz -C /data

# 3. 컨테이너 재시작
echo "🚀 컨테이너 재시작 중..."
docker-compose -f docker-compose.single.yml up -d

# 4. 데이터베이스 복원 (선택사항)
if [ -f "$BACKUP_DIR/database.sql.gz" ]; then
    echo "📊 데이터베이스 복원 중..."
    sleep 30  # 컨테이너 완전 시작 대기
    gunzip -c "$BACKUP_DIR/database.sql.gz" | docker exec -i regulations-app-1 psql -U postgres regulations_development
fi

echo "✅ 복원 완료!"
echo "🌐 서비스 확인: http://localhost:3000"