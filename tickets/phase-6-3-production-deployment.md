# Phase 6, Ticket 3: Production Deployment and Monitoring Setup

**Priority**: Medium  
**Estimated Time**: 4-5 hours  
**Prerequisites**: Completed Phase 6, Ticket 2  

## Objective

Prepare the application for production deployment with proper configuration, monitoring, logging, and deployment automation. Set up staging and production environments with appropriate security and performance configurations.

## Acceptance Criteria

- [ ] Production environment configuration completed
- [ ] Environment variables and secrets management
- [ ] Database configuration for production
- [ ] Background job processing setup
- [ ] File storage configuration (cloud storage)
- [ ] Monitoring and alerting implemented
- [ ] Logging configuration optimized
- [ ] Deployment automation scripts created
- [ ] Health checks and status endpoints
- [ ] Backup and recovery procedures documented

## Technical Requirements

### 1. Environment Configuration

Create `config/environments/production.rb` updates:

```ruby
Rails.application.configure do
  # Basic production settings
  config.cache_classes = true
  config.eager_load = true
  config.consider_all_requests_local = false
  config.action_controller.perform_caching = true

  # Asset configuration
  config.public_file_server.enabled = ENV['RAILS_SERVE_STATIC_FILES'].present?
  config.assets.compile = false
  config.assets.digest = true
  config.assets.css_compressor = :sass
  config.assets.js_compressor = :terser

  # Logging
  config.log_level = :info
  config.log_formatter = ::Logger::Formatter.new
  config.logger = ActiveSupport::TaggedLogging.new(
    ActiveSupport::Logger.new(STDOUT)
  )

  # Force SSL
  config.force_ssl = true
  config.ssl_options = {
    hsts: { expires: 1.year, subdomains: true, preload: true }
  }

  # Active Storage for production
  config.active_storage.service = :amazon
  config.active_storage.variant_processor = :mini_magick

  # Caching
  config.cache_store = :redis_cache_store, {
    url: ENV.fetch('REDIS_URL'),
    pool_size: ENV.fetch('RAILS_MAX_THREADS', 5),
    pool_timeout: 5
  }

  # Action Mailer
  config.action_mailer.perform_caching = false
  config.action_mailer.perform_deliveries = true
  config.action_mailer.raise_delivery_errors = true
  config.action_mailer.default_url_options = { 
    host: ENV.fetch('APP_HOST'), 
    protocol: 'https' 
  }

  # Email delivery
  config.action_mailer.delivery_method = :smtp
  config.action_mailer.smtp_settings = {
    address: ENV.fetch('SMTP_HOST'),
    port: ENV.fetch('SMTP_PORT', 587),
    domain: ENV.fetch('SMTP_DOMAIN'),
    user_name: ENV.fetch('SMTP_USERNAME'),
    password: ENV.fetch('SMTP_PASSWORD'),
    authentication: :plain,
    enable_starttls_auto: true
  }

  # Performance
  config.middleware.use Rack::Deflate
  config.middleware.use Rack::Attack

  # Security
  config.assume_ssl = true
  config.force_ssl = true
end
```

Create `config/environments/staging.rb`:

```ruby
# Staging environment - similar to production but with debug info
require_relative "production"

Rails.application.configure do
  # Allow some debugging in staging
  config.log_level = :debug
  config.consider_all_requests_local = false

  # Use staging-specific services
  config.active_storage.service = :amazon_staging
  
  # Staging-specific email settings
  config.action_mailer.default_url_options = { 
    host: ENV.fetch('STAGING_HOST'), 
    protocol: 'https' 
  }

  # Less aggressive caching for testing
  config.cache_store = :redis_cache_store, {
    url: ENV.fetch('STAGING_REDIS_URL'),
    expires_in: 30.minutes
  }
end
```

### 2. Storage Configuration

Update `config/storage.yml`:

```yaml
test:
  service: Disk
  root: <%= Rails.root.join("tmp/storage") %>

local:
  service: Disk
  root: <%= Rails.root.join("storage") %>

amazon:
  service: S3
  access_key_id: <%= ENV['AWS_ACCESS_KEY_ID'] %>
  secret_access_key: <%= ENV['AWS_SECRET_ACCESS_KEY'] %>
  region: <%= ENV['AWS_REGION'] %>
  bucket: <%= ENV['AWS_S3_BUCKET'] %>
  public: false

amazon_staging:
  service: S3
  access_key_id: <%= ENV['AWS_ACCESS_KEY_ID'] %>
  secret_access_key: <%= ENV['AWS_SECRET_ACCESS_KEY'] %>
  region: <%= ENV['AWS_REGION'] %>
  bucket: <%= ENV['AWS_S3_STAGING_BUCKET'] %>
  public: false

# Google Cloud Storage alternative
# google:
#   service: GCS
#   project: <%= ENV['GOOGLE_CLOUD_PROJECT'] %>
#   credentials: <%= ENV['GOOGLE_CLOUD_KEYFILE'] %>
#   bucket: <%= ENV['GOOGLE_CLOUD_BUCKET'] %>
#   public: false
```

### 3. Database Configuration

Update `config/database.yml`:

```yaml
default: &default
  adapter: postgresql
  encoding: unicode
  pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>

development:
  <<: *default
  database: family_photo_share_development
  username: <%= ENV.fetch("DATABASE_USERNAME", "postgres") %>
  password: <%= ENV.fetch("DATABASE_PASSWORD", "") %>
  host: <%= ENV.fetch("DATABASE_HOST", "localhost") %>

test:
  <<: *default
  database: family_photo_share_test<%= ENV['TEST_ENV_NUMBER'] %>
  username: <%= ENV.fetch("DATABASE_USERNAME", "postgres") %>
  password: <%= ENV.fetch("DATABASE_PASSWORD", "") %>
  host: <%= ENV.fetch("DATABASE_HOST", "localhost") %>

staging:
  <<: *default
  url: <%= ENV['STAGING_DATABASE_URL'] %>
  pool: 10
  checkout_timeout: 5
  reaping_frequency: 10
  dead_connection_timeout: 5

production:
  <<: *default
  url: <%= ENV['DATABASE_URL'] %>
  pool: <%= ENV.fetch("DB_POOL", 20) %>
  checkout_timeout: 5
  reaping_frequency: 10
  dead_connection_timeout: 5
  # SSL configuration for cloud databases
  sslmode: require
  variables:
    statement_timeout: 15s
    lock_timeout: 10s
```

### 4. Environment Variables Template

Create `.env.production.example`:

```bash
# Application Settings
RAILS_ENV=production
RACK_ENV=production
APP_HOST=familyphotoshare.com
SECRET_KEY_BASE=your_secret_key_base_here

# Database
DATABASE_URL=postgresql://username:password@host:5432/family_photo_share_production
DB_POOL=20

# Redis
REDIS_URL=redis://redis-host:6379/0

# File Storage (AWS S3)
AWS_ACCESS_KEY_ID=your_access_key
AWS_SECRET_ACCESS_KEY=your_secret_key
AWS_REGION=us-east-1
AWS_S3_BUCKET=family-photo-share-production
AWS_S3_STAGING_BUCKET=family-photo-share-staging

# Email (SMTP)
SMTP_HOST=smtp.example.com
SMTP_PORT=587
SMTP_DOMAIN=familyphotoshare.com
SMTP_USERNAME=noreply@familyphotoshare.com
SMTP_PASSWORD=your_smtp_password

# OAuth
GOOGLE_CLIENT_ID=your_google_client_id
GOOGLE_CLIENT_SECRET=your_google_client_secret

# Monitoring
HONEYBADGER_API_KEY=your_honeybadger_key
NEW_RELIC_LICENSE_KEY=your_newrelic_key

# Performance
RAILS_MAX_THREADS=5
WEB_CONCURRENCY=2

# Rate Limiting
RACK_ATTACK_ENABLE=true

# Feature Flags
ENABLE_REGISTRATION=true
ENABLE_EMAIL_INVITATIONS=true
```

### 5. Health Checks and Status

Create `app/controllers/health_controller.rb`:

```ruby
class HealthController < ApplicationController
  skip_before_action :authenticate_user!
  skip_before_action :verify_authenticity_token

  def index
    render json: {
      status: 'ok',
      timestamp: Time.current.iso8601,
      version: ENV['APP_VERSION'] || 'unknown',
      environment: Rails.env
    }
  end

  def detailed
    checks = {
      database: check_database,
      redis: check_redis,
      storage: check_storage,
      sidekiq: check_sidekiq
    }

    overall_status = checks.values.all? { |check| check[:status] == 'ok' } ? 'ok' : 'error'

    render json: {
      status: overall_status,
      timestamp: Time.current.iso8601,
      checks: checks
    }, status: overall_status == 'ok' ? 200 : 503
  end

  private

  def check_database
    ActiveRecord::Base.connection.execute('SELECT 1')
    { status: 'ok', message: 'Database connection successful' }
  rescue => e
    { status: 'error', message: "Database error: #{e.message}" }
  end

  def check_redis
    Rails.cache.write('health_check', Time.current.to_i)
    value = Rails.cache.read('health_check')
    
    if value
      { status: 'ok', message: 'Redis connection successful' }
    else
      { status: 'error', message: 'Redis read/write failed' }
    end
  rescue => e
    { status: 'error', message: "Redis error: #{e.message}" }
  end

  def check_storage
    # Test Active Storage connection
    ActiveStorage::Blob.service.exist?('health_check_key')
    { status: 'ok', message: 'Storage service accessible' }
  rescue => e
    { status: 'error', message: "Storage error: #{e.message}" }
  end

  def check_sidekiq
    stats = Sidekiq::Stats.new
    if stats.processed > 0 || stats.enqueued == 0
      { 
        status: 'ok', 
        message: 'Sidekiq operational',
        processed: stats.processed,
        enqueued: stats.enqueued,
        failed: stats.failed
      }
    else
      { status: 'warning', message: 'Sidekiq may not be processing jobs' }
    end
  rescue => e
    { status: 'error', message: "Sidekiq error: #{e.message}" }
  end
end
```

Update routes:

```ruby
Rails.application.routes.draw do
  # Health check endpoints
  get '/health', to: 'health#index'
  get '/health/detailed', to: 'health#detailed'
  
  # ... existing routes ...
end
```

### 6. Monitoring and Logging

Create `config/initializers/logging.rb`:

```ruby
if Rails.env.production? || Rails.env.staging?
  # Structured logging for production
  Rails.application.configure do
    config.log_formatter = proc do |severity, datetime, progname, msg|
      {
        timestamp: datetime.iso8601,
        level: severity,
        message: msg,
        environment: Rails.env,
        application: 'family-photo-share'
      }.to_json + "\n"
    end
  end

  # Custom log tags
  Rails.application.configure do
    config.log_tags = [
      :request_id,
      -> request { "IP:#{request.remote_ip}" },
      -> request { "User:#{request.env['warden']&.user&.id || 'anonymous'}" }
    ]
  end
end

# Performance logging
ActiveSupport::Notifications.subscribe 'process_action.action_controller' do |name, started, finished, unique_id, data|
  duration = finished - started
  
  if duration > 1.0 # Log requests taking more than 1 second
    Rails.logger.warn({
      event: 'slow_request',
      controller: data[:controller],
      action: data[:action],
      duration: duration.round(3),
      view_runtime: data[:view_runtime]&.round(3),
      db_runtime: data[:db_runtime]&.round(3)
    }.to_json)
  end
end

# Database query logging
ActiveSupport::Notifications.subscribe 'sql.active_record' do |name, started, finished, unique_id, data|
  duration = finished - started
  
  if duration > 0.5 # Log slow queries
    Rails.logger.warn({
      event: 'slow_query',
      sql: data[:sql],
      duration: duration.round(3),
      binds: data[:type_casted_binds]
    }.to_json)
  end
end
```

Create `config/initializers/monitoring.rb`:

```ruby
# Error tracking configuration (Honeybadger example)
if Rails.env.production? && ENV['HONEYBADGER_API_KEY'].present?
  Honeybadger.configure do |config|
    config.api_key = ENV['HONEYBADGER_API_KEY']
    config.environment = Rails.env
    config.report_data = true
  end
end

# Application Performance Monitoring (New Relic example)
if Rails.env.production? && ENV['NEW_RELIC_LICENSE_KEY'].present?
  # New Relic configuration would go here
end

# Custom metrics
class ApplicationMetrics
  def self.increment(metric, value = 1, tags = {})
    Rails.logger.info({
      event: 'metric',
      name: metric,
      value: value,
      tags: tags
    }.to_json)
  end

  def self.timing(metric, duration, tags = {})
    Rails.logger.info({
      event: 'timing',
      name: metric,
      duration: duration,
      tags: tags
    }.to_json)
  end
end

# Track important business metrics
ActiveSupport::Notifications.subscribe 'photo.uploaded' do |name, started, finished, unique_id, data|
  ApplicationMetrics.increment('photos.uploaded', 1, {
    user_id: data[:user_id],
    family_id: data[:family_id]
  })
end

ActiveSupport::Notifications.subscribe 'family.created' do |name, started, finished, unique_id, data|
  ApplicationMetrics.increment('families.created', 1, {
    user_id: data[:user_id]
  })
end
```

### 7. Deployment Scripts

Create `bin/deploy`:

```bash
#!/bin/bash
set -e

echo "Starting deployment..."

# Environment setup
ENVIRONMENT=${1:-production}
echo "Deploying to: $ENVIRONMENT"

# Pre-deployment checks
echo "Running pre-deployment checks..."
bundle exec rails db:migrate:status
bundle exec rails assets:precompile

# Database migration
echo "Running database migrations..."
bundle exec rails db:migrate RAILS_ENV=$ENVIRONMENT

# Clear cache
echo "Clearing cache..."
bundle exec rails cache:clear RAILS_ENV=$ENVIRONMENT

# Restart background jobs
echo "Restarting Sidekiq..."
sudo systemctl restart sidekiq

# Restart web server (example for systemd)
echo "Restarting web server..."
sudo systemctl restart family-photo-share

# Post-deployment verification
echo "Running post-deployment checks..."
sleep 5
curl -f http://localhost/health || exit 1

echo "Deployment completed successfully!"
```

Create `bin/backup`:

```bash
#!/bin/bash
set -e

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/var/backups/family-photo-share"
DATABASE_URL=${DATABASE_URL}

echo "Starting backup process..."

# Create backup directory
mkdir -p $BACKUP_DIR

# Database backup
echo "Backing up database..."
pg_dump $DATABASE_URL | gzip > "$BACKUP_DIR/database_$TIMESTAMP.sql.gz"

# File storage backup (if using local storage)
if [ -d "storage" ]; then
  echo "Backing up uploaded files..."
  tar -czf "$BACKUP_DIR/storage_$TIMESTAMP.tar.gz" storage/
fi

# Application code backup
echo "Backing up application code..."
tar --exclude='.git' --exclude='log/*' --exclude='tmp/*' \
    -czf "$BACKUP_DIR/application_$TIMESTAMP.tar.gz" .

# Cleanup old backups (keep last 7 days)
find $BACKUP_DIR -name "*.gz" -mtime +7 -delete

echo "Backup completed: $BACKUP_DIR"
ls -la $BACKUP_DIR/*$TIMESTAMP*
```

Create `config/deploy.yml` (for deployment automation):

```yaml
# Example deployment configuration
production:
  host: your-production-server.com
  user: deploy
  path: /var/www/family-photo-share
  branch: main
  
  pre_deploy:
    - bundle install --deployment --without development test
    - yarn install --production
    - rails assets:precompile
    
  deploy:
    - rails db:migrate
    - rails cache:clear
    
  post_deploy:
    - sudo systemctl restart family-photo-share
    - sudo systemctl restart sidekiq
    - curl -f http://localhost/health

staging:
  host: staging.familyphotoshare.com
  user: deploy
  path: /var/www/family-photo-share-staging
  branch: develop
  
  pre_deploy:
    - bundle install --deployment --without development test
    - yarn install --production
    - rails assets:precompile RAILS_ENV=staging
    
  deploy:
    - rails db:migrate RAILS_ENV=staging
    - rails cache:clear RAILS_ENV=staging
    
  post_deploy:
    - sudo systemctl restart family-photo-share-staging
    - sudo systemctl restart sidekiq-staging
```

### 8. Systemd Service Files

Create `/etc/systemd/system/family-photo-share.service`:

```ini
[Unit]
Description=Family Photo Share Rails Application
After=network.target

[Service]
Type=simple
User=deploy
WorkingDirectory=/var/www/family-photo-share
Environment=RAILS_ENV=production
Environment=RACK_ENV=production
EnvironmentFile=/var/www/family-photo-share/.env.production
ExecStart=/usr/local/bin/bundle exec puma -C config/puma.rb
ExecReload=/bin/kill -SIGUSR1 $MAINPID
TimeoutSec=15
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

Create `/etc/systemd/system/sidekiq.service`:

```ini
[Unit]
Description=Sidekiq Background Jobs
After=network.target

[Service]
Type=simple
User=deploy
WorkingDirectory=/var/www/family-photo-share
Environment=RAILS_ENV=production
Environment=RACK_ENV=production
EnvironmentFile=/var/www/family-photo-share/.env.production
ExecStart=/usr/local/bin/bundle exec sidekiq -C config/sidekiq.yml
ExecReload=/bin/kill -TSTP $MAINPID
TimeoutSec=15
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

### 9. Puma Configuration

Create `config/puma.rb`:

```ruby
# Puma configuration for production
max_threads_count = ENV.fetch("RAILS_MAX_THREADS") { 5 }
min_threads_count = ENV.fetch("RAILS_MIN_THREADS") { max_threads_count }
threads min_threads_count, max_threads_count

# Worker processes for production
if ENV["RAILS_ENV"] == "production"
  workers ENV.fetch("WEB_CONCURRENCY") { 2 }
  
  # Preload the application for memory efficiency
  preload_app!
  
  # Worker timeout
  worker_timeout 30
  
  # Worker boot timeout
  worker_boot_timeout 10
  
  # Worker shutdown timeout
  worker_shutdown_timeout 8
end

# Bind to port
port ENV.fetch("PORT") { 3000 }

# Bind to socket (for nginx proxy)
if ENV["PUMA_SOCKET"]
  bind "unix://#{ENV['PUMA_SOCKET']}"
end

# Set environment
environment ENV.fetch("RAILS_ENV") { "development" }

# PID file
pidfile ENV.fetch("PIDFILE") { "tmp/pids/puma.pid" }

# State file
state_path "tmp/pids/puma.state"

# Logging
stdout_redirect "log/puma.stdout.log", "log/puma.stderr.log", true

# Preloading for memory efficiency
on_worker_boot do
  # Reconnect to database
  ActiveRecord::Base.establish_connection if defined?(ActiveRecord)
  
  # Reconnect to Redis
  if defined?(Redis)
    Redis.current.disconnect!
  end
end

# Application restart hooks
before_fork do
  # Disconnect from database
  ActiveRecord::Base.connection_pool.disconnect! if defined?(ActiveRecord)
end

# Memory and CPU monitoring
if ENV["RAILS_ENV"] == "production"
  lowlevel_error_handler do |ex, env|
    # Log the error
    Rails.logger.error "Puma low-level error: #{ex.message}"
    [500, {}, ["Internal Server Error"]]
  end
end
```

### 10. Nginx Configuration

Create `/etc/nginx/sites-available/family-photo-share`:

```nginx
upstream family_photo_share {
  server unix:///var/www/family-photo-share/tmp/sockets/puma.sock fail_timeout=0;
}

server {
  listen 80;
  server_name familyphotoshare.com www.familyphotoshare.com;
  return 301 https://$server_name$request_uri;
}

server {
  listen 443 ssl http2;
  server_name familyphotoshare.com www.familyphotoshare.com;

  root /var/www/family-photo-share/public;

  # SSL configuration
  ssl_certificate /path/to/ssl/cert.pem;
  ssl_certificate_key /path/to/ssl/private.key;
  ssl_protocols TLSv1.2 TLSv1.3;
  ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384;
  ssl_prefer_server_ciphers off;

  # Security headers
  add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;
  add_header X-Frame-Options DENY always;
  add_header X-Content-Type-Options nosniff always;
  add_header X-XSS-Protection "1; mode=block" always;

  # Gzip compression
  gzip on;
  gzip_vary on;
  gzip_min_length 1024;
  gzip_proxied any;
  gzip_comp_level 6;
  gzip_types
    text/plain
    text/css
    text/xml
    text/javascript
    application/json
    application/javascript
    application/xml+rss
    application/atom+xml
    image/svg+xml;

  # Static assets
  location ~ ^/(assets|packs)/ {
    expires 1y;
    add_header Cache-Control "public, immutable";
    try_files $uri =404;
  }

  # Health check endpoint
  location /health {
    try_files $uri @app;
  }

  # Main application
  location / {
    try_files $uri @app;
  }

  location @app {
    proxy_pass http://family_photo_share;
    proxy_set_header Host $http_host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_redirect off;
    
    # Timeout settings
    proxy_connect_timeout 60s;
    proxy_send_timeout 60s;
    proxy_read_timeout 60s;
    
    # File upload size
    client_max_body_size 10M;
  }

  # Error pages
  error_page 500 502 503 504 /500.html;
  location = /500.html {
    root /var/www/family-photo-share/public;
  }
}
```

## Testing Requirements

### 1. Deployment Tests
Create `spec/deployment/health_check_spec.rb`:

```ruby
require 'rails_helper'

RSpec.describe HealthController, type: :request do
  describe 'GET /health' do
    it 'returns basic health status' do
      get '/health'
      
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['status']).to eq('ok')
      expect(json['environment']).to eq('test')
    end
  end

  describe 'GET /health/detailed' do
    it 'returns detailed health checks' do
      get '/health/detailed'
      
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['checks']).to have_key('database')
      expect(json['checks']).to have_key('redis')
      expect(json['checks']['database']['status']).to eq('ok')
    end
  end
end
```

### 2. Configuration Tests
Create `spec/deployment/configuration_spec.rb`:

```ruby
require 'rails_helper'

RSpec.describe 'Production Configuration', type: :configuration do
  it 'has required environment variables in production' do
    # Skip in test environment
    skip unless Rails.env.production?

    required_vars = %w[
      DATABASE_URL
      REDIS_URL
      SECRET_KEY_BASE
      AWS_ACCESS_KEY_ID
      AWS_SECRET_ACCESS_KEY
      AWS_REGION
      AWS_S3_BUCKET
    ]

    required_vars.each do |var|
      expect(ENV[var]).to be_present, "#{var} environment variable is required"
    end
  end

  it 'configures Active Storage correctly' do
    expect(Rails.application.config.active_storage.service).to be_present
  end

  it 'configures caching correctly' do
    expect(Rails.cache).to be_a(ActiveSupport::Cache::RedisCacheStore) if Rails.env.production?
  end
end
```

## Files to Create/Modify

- `config/environments/production.rb` - Production configuration
- `config/environments/staging.rb` - Staging configuration
- `config/storage.yml` - Storage service configuration
- `config/database.yml` - Database configuration
- `config/puma.rb` - Puma web server configuration
- `app/controllers/health_controller.rb` - Health check endpoints
- `config/initializers/logging.rb` - Production logging
- `config/initializers/monitoring.rb` - Monitoring setup
- `bin/deploy` - Deployment script
- `bin/backup` - Backup script
- `.env.production.example` - Environment variables template
- Systemd service files
- Nginx configuration
- Deployment and configuration tests

## Deliverables

1. Complete production environment configuration
2. Health check and monitoring endpoints
3. Deployment automation scripts
4. Database and file storage configuration
5. Background job processing setup
6. Security and performance optimizations
7. Backup and recovery procedures
8. Monitoring and alerting setup

## Deployment Checklist

### Pre-Deployment
- [ ] Set up production server with required dependencies
- [ ] Configure environment variables
- [ ] Set up SSL certificates
- [ ] Configure database and Redis
- [ ] Set up AWS S3 or cloud storage
- [ ] Configure email delivery service

### Initial Deployment
- [ ] Clone repository to production server
- [ ] Install dependencies (bundle install, yarn install)
- [ ] Run database migrations
- [ ] Precompile assets
- [ ] Set up systemd services
- [ ] Configure nginx or web server
- [ ] Test health endpoints

### Post-Deployment
- [ ] Verify application functionality
- [ ] Test file uploads to cloud storage
- [ ] Test email delivery
- [ ] Monitor application logs
- [ ] Set up monitoring and alerting
- [ ] Configure backup procedures

## Security Considerations

1. **Server Security**:
   - Keep server OS and packages updated
   - Configure firewall (only allow necessary ports)
   - Use non-root user for application
   - Disable password authentication (use SSH keys)

2. **Application Security**:
   - Use strong secret keys
   - Enable SSL/TLS with strong ciphers
   - Configure security headers
   - Regular security updates

3. **Database Security**:
   - Use strong database passwords
   - Enable SSL for database connections
   - Regular database backups
   - Restrict database access

## Monitoring and Alerting

Set up alerts for:
- Application errors (500 errors)
- High response times (>2 seconds)
- Database connection issues
- High memory/CPU usage
- Disk space warnings
- Background job failures

## Backup Strategy

1. **Database Backups**:
   - Daily automated backups
   - Test restore procedures monthly
   - Keep backups for 30 days

2. **File Storage**:
   - Cloud storage with versioning
   - Cross-region replication
   - Regular backup verification

3. **Application Code**:
   - Git repository backups
   - Configuration file backups
   - Deployment rollback procedures

## Next Steps

After completing this ticket, the application should be ready for production use. Consider implementing:

1. **Continuous Integration/Deployment** (CI/CD)
2. **Load balancing** for high traffic
3. **Content Delivery Network** (CDN) for global performance
4. **Database read replicas** for scaling
5. **Advanced monitoring** with custom dashboards
6. **User analytics** and usage tracking
7. **A/B testing** framework for feature experimentation

The development process is now complete! The junior engineer should have a fully functional, secure, and scalable family photo sharing application ready for production deployment.