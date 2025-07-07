# Rails 8 + PostgreSQL + pgvector 개발 환경

FROM ruby:3.3-alpine

# 시스템 패키지 및 PostgreSQL 클라이언트 설치
RUN apk add --no-cache \
    build-base \
    git \
    postgresql-dev \
    postgresql-client \
    nodejs \
    npm \
    yarn \
    tzdata \
    yaml-dev \
    curl \
    && rm -rf /var/cache/apk/*

# 작업 디렉토리 설정
WORKDIR /app

# Ruby 최신 버전의 Bundler 설치
RUN gem install bundler

# 애플리케이션 코드 복사
COPY . .

# Rails 프로젝트 초기화 실행 (필요시)
RUN chmod +x init_rails.sh && ./init_rails.sh

# 환경변수 설정
ENV RAILS_ENV=development
ENV BUNDLE_PATH=/bundle
ENV BUNDLE_BIN=/bundle/bin
ENV PATH=$BUNDLE_BIN:$PATH

# 애플리케이션 포트
EXPOSE 3000

# 헬스체크 추가
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:3000/healthz || exit 1

# 개발 서버 시작 명령
CMD ["rails", "server", "-b", "0.0.0.0"]
