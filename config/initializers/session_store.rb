# Redis Session Store Configuration
Rails.application.configure do
  config.session_store :redis_session_store,
    key: '_regulations_session',
    redis: {
      url: ENV.fetch('REDIS_URL', 'redis://redis:6379/1'),
      key_prefix: 'regulations:session:',
      db: 1,
      expire_after: 4.hours
    },
    secure: Rails.env.production?,
    httponly: true,
    same_site: :lax,
    expire_after: 4.hours,
    serializer: :json
end