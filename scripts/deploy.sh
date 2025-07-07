#!/bin/bash
# 규정 관리 시스템 배포 스크립트

set -e

ENVIRONMENT=${1:-development}
DOCKER_IMAGE=${2:-regulations-app:latest}

echo "🚀 배포 시작 - 환경: $ENVIRONMENT, 이미지: $DOCKER_IMAGE"

case $ENVIRONMENT in
    "development"|"dev")
        echo "🔧 개발 환경 배포"
        docker-compose -f docker-compose.single.yml down
        docker-compose -f docker-compose.single.yml up -d
        ;;
    "production"|"prod")
        echo "🌐 프로덕션 환경 배포"
        
        # 환경변수 확인
        if [ ! -f ".env.production" ]; then
            echo "❌ .env.production 파일이 필요합니다"
            echo "📝 .env.example을 참고하여 생성하세요"
            exit 1
        fi
        
        # 프로덕션 배포
        export DOCKER_IMAGE="$DOCKER_IMAGE"
        docker-compose -f docker-compose.prod.yml down
        docker-compose -f docker-compose.prod.yml pull
        docker-compose -f docker-compose.prod.yml up -d
        ;;
    "github")
        echo "🐙 GitHub Container Registry에서 배포"
        
        # GitHub 이미지 pull
        docker pull ghcr.io/yourusername/regulations-system:latest
        docker tag ghcr.io/yourusername/regulations-system:latest regulations-app:latest
        
        # 배포 실행
        docker-compose -f docker-compose.single.yml down
        docker-compose -f docker-compose.single.yml up -d
        ;;
    *)
        echo "❌ 지원하지 않는 환경: $ENVIRONMENT"
        echo "사용법: $0 [development|production|github] [docker-image]"
        exit 1
        ;;
esac

# 헬스체크
echo "⏳ 서비스 시작 대기 중..."
sleep 30

if curl -f http://localhost:3000/up > /dev/null 2>&1; then
    echo "✅ 배포 성공! 서비스가 정상 작동 중입니다."
    echo "🌐 접속 URL: http://localhost:3000"
else
    echo "❌ 배포 실패! 서비스가 응답하지 않습니다."
    echo "📋 로그 확인: docker logs regulations-app-1"
    exit 1
fi