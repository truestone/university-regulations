#!/bin/sh
set -e

echo "🚀 Rails 8 프로젝트 초기화 시작..."

# Rails 프로젝트가 이미 존재하는지 확인
if [ -f "Gemfile" ]; then
  echo "✅ Rails 프로젝트가 이미 존재합니다. 번들 설치만 진행합니다."
  bundle install
  exit 0
fi

echo "📦 새로운 Rails 8 프로젝트 생성 중..."

# Rails 8 프로젝트 생성
rails new . \
  --database=postgresql \
  --skip-git \
  --skip-test \
  --css=tailwind \
  --javascript=hotwire \
  --api=false \
  --force

echo "🔧 필수 Gem 추가 중..."

# Gemfile에 필수 gem 추가
cat >> Gemfile << 'EOF'

# AI 및 벡터 검색
gem 'pgvector'
gem 'ruby-openai'
gem 'anthropic'

# 백그라운드 작업
gem 'sidekiq'

# 인증
gem 'bcrypt'

# 관리자 인터페이스
gem 'rails_admin'

# 환경변수 관리
gem 'dotenv-rails'

group :development, :test do
  gem 'rspec-rails'
  gem 'factory_bot_rails'
  gem 'rubocop'
  gem 'rubocop-rails'
  gem 'rubocop-rspec'
end

group :development do
  gem 'annotate'
end
EOF

echo "📦 Bundle 설치 중..."
bundle install

echo "🔧 Rails 설정 파일 생성 중..."

# database.yml 설정
cat > config/database.yml << 'EOF'
default: &default
  adapter: postgresql
  encoding: unicode
  pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>
  url: <%= ENV['DATABASE_URL'] %>

development:
  <<: *default
  database: regulations_development

test:
  <<: *default
  database: regulations_test

production:
  <<: *default
  database: regulations_production
EOF

echo "✅ Rails 8 프로젝트 초기화 완료!"
echo "🐳 다음 명령어로 서버를 시작하세요:"
echo "   docker-compose up"
