# frozen_string_literal: true

# Sidekiq 설정
Sidekiq.configure_server do |config|
  config.redis = { url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0') }
  
  # 큐별 동시 실행 수 설정
  config.concurrency = 5
  
  # 로깅 설정
  config.logger.level = Logger::INFO
end

Sidekiq.configure_client do |config|
  config.redis = { url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0') }
end

# 큐별 설정
Sidekiq.default_job_options = {
  'backtrace' => true,
  'retry' => 3
}

# 큐별 설정
# 큐 설정은 sidekiq.yml 파일이나 실행 시 옵션으로 설정