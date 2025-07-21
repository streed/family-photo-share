# Redis configuration for Sidekiq and caching
redis_url = ENV.fetch('REDIS_URL', 'redis://localhost:6380/0')

# Configure Redis connection pool
$redis = Redis.new(url: redis_url)