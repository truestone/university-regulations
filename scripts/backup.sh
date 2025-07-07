#!/bin/bash
# 규정 관리 시스템 백업 스크립트

set -e

BACKUP_DIR="backups/$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

echo "🔄 백업 시작: $BACKUP_DIR"

# 1. PostgreSQL 데이터 덤프
echo "📊 PostgreSQL 데이터베이스 백업 중..."
docker exec regulations-app-1 pg_dump -U postgres regulations_development | gzip > "$BACKUP_DIR/database.sql.gz"

# 2. Docker 볼륨 백업
echo "💾 PostgreSQL 볼륨 백업 중..."
docker run --rm -v regulations_postgres_data:/data -v "$(pwd)/$BACKUP_DIR":/backup alpine tar czf /backup/postgres-volume.tar.gz -C /data .

echo "🔄 Redis 볼륨 백업 중..."
docker run --rm -v regulations_redis_data:/data -v "$(pwd)/$BACKUP_DIR":/backup alpine tar czf /backup/redis-volume.tar.gz -C /data .

# 3. 설정 파일 백업
echo "⚙️ 설정 파일 백업 중..."
cp docker-compose.single.yml "$BACKUP_DIR/"
cp docker-compose.prod.yml "$BACKUP_DIR/"
cp .env.example "$BACKUP_DIR/"

# 4. 백업 정보 생성
echo "📝 백업 정보 생성 중..."
cat > "$BACKUP_DIR/backup-info.txt" << EOF
백업 생성 시간: $(date)
Docker 이미지: $(docker images regulations-app --format "{{.Repository}}:{{.Tag}} ({{.Size}})")
컨테이너 상태: $(docker ps --filter name=regulations-app-1 --format "{{.Status}}")
볼륨 크기:
$(docker system df -v | grep regulations)
EOF

echo "✅ 백업 완료: $BACKUP_DIR"
echo "📁 백업 파일 목록:"
ls -la "$BACKUP_DIR"