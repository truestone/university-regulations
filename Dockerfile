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
    && rm -rf /var/cache/apk/*

# 작업 디렉토리 설정
WORKDIR /app

# Ruby 최신 버전의 Bundler 설치
RUN gem install bundler

# 환경변수 설정
ENV RAILS_ENV=development
ENV BUNDLE_PATH=/bundle
ENV BUNDLE_BIN=/bundle/bin
ENV PATH=$BUNDLE_BIN:$PATH

# 애플리케이션 포트
EXPOSE 3000

# 개발 서버 시작 명령
CMD ["rails", "server", "-b", "0.0.0.0"]
