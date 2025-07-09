# Redis Configuration
redis_url = ENV.fetch('REDIS_URL', 'redis://redis:6379/0')

# Redis connection for general use
$redis = Redis.new(url: redis_url)

# Redis connection pool for sessions
REDIS_POOL = ConnectionPool.new(size: 10, timeout: 5) do
  Redis.new(url: redis_url)
end

# Test Redis connection
begin
  $redis.ping
  Rails.logger.info "Redis connection established successfully"
rescue Redis::CannotConnectError => e
  Rails.logger.error "Failed to connect to Redis: #{e.message}"
end

# Redis configuration for different environments
Rails.application.configure do
  case Rails.env
  when 'development'
    config.cache_store = :redis_cache_store, { url: redis_url, db: 0 }
  when 'test'
    config.cache_store = :redis_cache_store, { url: redis_url, db: 2 }
  when 'production'
    config.cache_store = :redis_cache_store, { 
      url: redis_url, 
      db: 0,
      pool_size: 20,
      pool_timeout: 5
    }
  end
end