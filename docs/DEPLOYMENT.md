# Family Photo Share Deployment Guide

This guide covers various deployment options for Family Photo Share, from development to production environments.

## Table of Contents

- [Quick Start](#quick-start)
- [Docker Deployment](#docker-deployment)
- [Cloud Deployment](#cloud-deployment)
- [Environment Configuration](#environment-configuration)
- [Database Setup](#database-setup)
- [Storage Configuration](#storage-configuration)
- [Background Jobs](#background-jobs)
- [SSL/TLS Configuration](#ssltls-configuration)
- [Monitoring](#monitoring)
- [Backup Strategy](#backup-strategy)
- [Troubleshooting](#troubleshooting)

## Quick Start

### Local Development

```bash
# Clone and setup
git clone https://github.com/yourusername/family-photo-share.git
cd family-photo-share
cp .env.example .env

# Using Docker (recommended)
docker-compose up -d
docker-compose exec web rails db:create db:migrate db:seed

# Visit http://localhost:3000
```

### Production with Docker

```bash
# Setup production environment
cp .env.production.example .env.production
# Edit .env.production with your values

# Deploy
docker-compose -f docker-compose.production.yml up -d
```

## Docker Deployment

### Development Environment

The development environment includes:
- Web server (Rails)
- PostgreSQL database
- Redis for caching/jobs
- Multiple Sidekiq workers
- Volume mounts for live code reloading

```yaml
# docker-compose.yml
services:
  web:
    build:
      context: .
      dockerfile: Dockerfile.dev
    ports:
      - "3000:3000"
    volumes:
      - .:/rails
      - bundle_cache:/usr/local/bundle
```

**Commands:**
```bash
# Start all services
docker-compose up -d

# View logs
docker-compose logs -f web

# Access Rails console
docker-compose exec web rails console

# Run migrations
docker-compose exec web rails db:migrate

# Run tests
docker-compose exec web rspec
```

### Production Environment

The production environment is optimized for:
- Performance and security
- Minimal image size
- Health checks
- Resource limits

```yaml
# docker-compose.production.yml
services:
  web:
    image: family-photo-share:latest
    environment:
      RAILS_ENV: production
      RAILS_SERVE_STATIC_FILES: "true"
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
```

**Build and Deploy:**
```bash
# Build production image
docker build -t family-photo-share:latest -f Dockerfile .

# Tag for registry
docker tag family-photo-share:latest your-registry/family-photo-share:v1.0.0

# Push to registry
docker push your-registry/family-photo-share:v1.0.0

# Deploy
docker-compose -f docker-compose.production.yml up -d
```

## Cloud Deployment

### AWS Deployment

#### Using AWS ECS (Elastic Container Service)

1. **Create ECR Repository**
```bash
aws ecr create-repository --repository-name family-photo-share
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 123456789012.dkr.ecr.us-east-1.amazonaws.com
```

2. **Build and Push Image**
```bash
docker build -t family-photo-share .
docker tag family-photo-share:latest 123456789012.dkr.ecr.us-east-1.amazonaws.com/family-photo-share:latest
docker push 123456789012.dkr.ecr.us-east-1.amazonaws.com/family-photo-share:latest
```

3. **Create ECS Task Definition**
```json
{
  "family": "family-photo-share",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "512",
  "memory": "1024",
  "containerDefinitions": [
    {
      "name": "web",
      "image": "123456789012.dkr.ecr.us-east-1.amazonaws.com/family-photo-share:latest",
      "portMappings": [
        {
          "containerPort": 3000,
          "protocol": "tcp"
        }
      ],
      "environment": [
        {
          "name": "RAILS_ENV",
          "value": "production"
        },
        {
          "name": "DATABASE_URL",
          "value": "postgresql://user:pass@rds-endpoint:5432/dbname"
        }
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/family-photo-share",
          "awslogs-region": "us-east-1",
          "awslogs-stream-prefix": "ecs"
        }
      }
    }
  ]
}
```

4. **Infrastructure with Terraform**
```hcl
# main.tf
resource "aws_ecs_cluster" "main" {
  name = "family-photo-share"
}

resource "aws_ecs_service" "web" {
  name            = "family-photo-share-web"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.web.arn
  desired_count   = 2
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = var.private_subnet_ids
    security_groups = [aws_security_group.web.id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.web.arn
    container_name   = "web"
    container_port   = 3000
  }
}

resource "aws_rds_instance" "postgres" {
  identifier = "family-photo-share-db"
  engine     = "postgres"
  engine_version = "15.4"
  instance_class = "db.t3.micro"
  
  allocated_storage     = 20
  max_allocated_storage = 100
  storage_type          = "gp3"
  storage_encrypted     = true
  
  db_name  = "family_photo_share_production"
  username = "postgres"
  password = var.db_password
  
  vpc_security_group_ids = [aws_security_group.rds.id]
  db_subnet_group_name   = aws_db_subnet_group.main.name
  
  backup_retention_period = 7
  backup_window          = "03:00-04:00"
  maintenance_window     = "sun:04:00-sun:05:00"
  
  skip_final_snapshot = false
  final_snapshot_identifier = "family-photo-share-final-snapshot"
  
  tags = {
    Name = "family-photo-share-db"
  }
}

resource "aws_s3_bucket" "storage" {
  bucket = "family-photo-share-storage-${random_id.bucket_suffix.hex}"
}

resource "aws_s3_bucket_versioning" "storage" {
  bucket = aws_s3_bucket.storage.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_encryption" "storage" {
  bucket = aws_s3_bucket.storage.id

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }
}
```

#### Using AWS App Runner

```yaml
# apprunner.yaml
version: 1.0
runtime: docker
build:
  commands:
    build:
      - echo "Build started on `date`"
      - docker build -t family-photo-share .
run:
  runtime-version: latest
  command: ./bin/rails server -b 0.0.0.0 -p 8080
  network:
    port: 8080
    env_vars:
      - name: RAILS_ENV
        value: production
      - name: PORT
        value: 8080
```

### Google Cloud Platform

#### Using Cloud Run

1. **Build and Push to Container Registry**
```bash
# Configure Docker for GCP
gcloud auth configure-docker

# Build and push
docker build -t gcr.io/your-project/family-photo-share .
docker push gcr.io/your-project/family-photo-share
```

2. **Deploy to Cloud Run**
```bash
gcloud run deploy family-photo-share \
  --image gcr.io/your-project/family-photo-share \
  --platform managed \
  --region us-central1 \
  --allow-unauthenticated \
  --memory 1Gi \
  --cpu 1 \
  --max-instances 10 \
  --set-env-vars RAILS_ENV=production,DATABASE_URL="postgresql://..." \
  --set-cloudsql-instances your-project:us-central1:family-photo-share-db
```

3. **Infrastructure with Terraform**
```hcl
resource "google_cloud_run_service" "family_photo_share" {
  name     = "family-photo-share"
  location = "us-central1"

  template {
    spec {
      containers {
        image = "gcr.io/your-project/family-photo-share:latest"
        
        env {
          name  = "RAILS_ENV"
          value = "production"
        }
        
        env {
          name  = "DATABASE_URL"
          value_from {
            secret_key_ref {
              name = google_secret_manager_secret.database_url.secret_id
              key  = "latest"
            }
          }
        }
        
        resources {
          limits = {
            cpu    = "1000m"
            memory = "1Gi"
          }
        }
      }
    }
    
    annotations = {
      "run.googleapis.com/cloudsql-instances" = google_sql_database_instance.postgres.connection_name
    }
  }

  traffic {
    percent         = 100
    latest_revision = true
  }
}

resource "google_sql_database_instance" "postgres" {
  name             = "family-photo-share-db"
  database_version = "POSTGRES_15"
  region          = "us-central1"

  settings {
    tier = "db-f1-micro"
    
    backup_configuration {
      enabled    = true
      start_time = "03:00"
    }
    
    database_flags {
      name  = "shared_preload_libraries"
      value = "pg_stat_statements"
    }
  }
}
```

### Heroku Deployment

1. **Prepare Application**
```bash
# Create Procfile
echo "web: bundle exec puma -C config/puma.rb" > Procfile
echo "worker: bundle exec sidekiq" >> Procfile

# Create app.json for Heroku Button
cat > app.json << EOF
{
  "name": "Family Photo Share",
  "description": "A family photo sharing application",
  "keywords": ["rails", "photos", "family"],
  "website": "https://github.com/yourusername/family-photo-share",
  "repository": "https://github.com/yourusername/family-photo-share",
  "logo": "https://example.com/logo.png",
  "success_url": "/",
  "env": {
    "RAILS_MASTER_KEY": {
      "description": "Rails master key for encrypted credentials",
      "generator": "secret"
    },
    "RAILS_ENV": {
      "value": "production"
    }
  },
  "addons": [
    "heroku-postgresql:mini",
    "heroku-redis:mini"
  ],
  "buildpacks": [
    {
      "url": "heroku/ruby"
    }
  ]
}
EOF
```

2. **Deploy to Heroku**
```bash
# Create Heroku app
heroku create your-app-name

# Add addons
heroku addons:create heroku-postgresql:mini
heroku addons:create heroku-redis:mini

# Set environment variables
heroku config:set RAILS_MASTER_KEY=$(cat config/master.key)
heroku config:set RAILS_ENV=production

# Deploy
git push heroku main

# Run migrations
heroku run rails db:migrate

# Scale workers
heroku ps:scale worker=1
```

## Environment Configuration

### Required Environment Variables

```bash
# Rails Configuration
RAILS_ENV=production
RAILS_MASTER_KEY=your-master-key
SECRET_KEY_BASE=your-secret-key

# Database
DATABASE_URL=postgresql://user:password@host:5432/database

# Redis
REDIS_URL=redis://localhost:6379/0

# Application
APP_HOST=yourdomain.com
FORCE_SSL=true
RAILS_SERVE_STATIC_FILES=true
RAILS_LOG_TO_STDOUT=true
```

### Optional Environment Variables

```bash
# Storage (AWS S3)
AWS_ACCESS_KEY_ID=your-access-key
AWS_SECRET_ACCESS_KEY=your-secret
AWS_REGION=us-east-1
AWS_BUCKET=your-bucket-name

# Email (SMTP)
SMTP_ADDRESS=smtp.gmail.com
SMTP_PORT=587
SMTP_USERNAME=your-gmail@gmail.com
SMTP_PASSWORD=your-app-password
SMTP_DOMAIN=yourdomain.com

# Monitoring
SENTRY_DSN=https://your-sentry-dsn
NEW_RELIC_LICENSE_KEY=your-newrelic-key

# Performance
WEB_CONCURRENCY=2
MAX_THREADS=5
RAILS_MAX_THREADS=5
```

### Environment File Templates

**Development (.env.example):**
```bash
# Development environment template
RAILS_ENV=development
DATABASE_URL=postgresql://postgres:password@postgres:5432/family_photo_share_development
REDIS_URL=redis://redis:6379/0
RAILS_MASTER_KEY=generate_with_rails_secret
```

**Production (.env.production.example):**
```bash
# Production environment template
RAILS_ENV=production
RAILS_SERVE_STATIC_FILES=true
RAILS_LOG_TO_STDOUT=true
FORCE_SSL=true
APP_HOST=yourdomain.com
DATABASE_URL=postgresql://user:password@host:5432/database
REDIS_URL=redis://host:6379/0
RAILS_MASTER_KEY=your-production-master-key
SECRET_KEY_BASE=your-production-secret-key

# Storage
AWS_ACCESS_KEY_ID=your-key
AWS_SECRET_ACCESS_KEY=your-secret
AWS_REGION=us-east-1
AWS_BUCKET=your-bucket

# Email
SMTP_ADDRESS=smtp.gmail.com
SMTP_PORT=587
SMTP_USERNAME=your-email@gmail.com
SMTP_PASSWORD=your-app-password
```

## Database Setup

### PostgreSQL Configuration

#### Development
```yaml
# docker-compose.yml
postgres:
  image: postgres:15-alpine
  environment:
    POSTGRES_DB: family_photo_share_development
    POSTGRES_USER: postgres
    POSTGRES_PASSWORD: password
  volumes:
    - postgres_data:/var/lib/postgresql/data
```

#### Production Optimizations
```sql
-- postgresql.conf optimizations
shared_buffers = 256MB
effective_cache_size = 1GB
work_mem = 4MB
maintenance_work_mem = 64MB
checkpoint_completion_target = 0.9
wal_buffers = 16MB
default_statistics_target = 100
random_page_cost = 1.1
effective_io_concurrency = 200
```

### Database Migrations

```bash
# Run migrations
docker-compose exec web rails db:migrate

# Check migration status
docker-compose exec web rails db:migrate:status

# Rollback if needed
docker-compose exec web rails db:rollback

# Reset database (development only)
docker-compose exec web rails db:reset
```

### Database Backups

#### Automated Backups
```bash
#!/bin/bash
# backup.sh
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="family_photo_share_backup_$DATE.sql"

pg_dump $DATABASE_URL > $BACKUP_FILE
gzip $BACKUP_FILE

# Upload to S3
aws s3 cp $BACKUP_FILE.gz s3://your-backup-bucket/database/

# Clean up old backups (keep 30 days)
find . -name "family_photo_share_backup_*.sql.gz" -mtime +30 -delete
```

#### Restore from Backup
```bash
# Restore database
gunzip family_photo_share_backup_20240115_120000.sql.gz
psql $DATABASE_URL < family_photo_share_backup_20240115_120000.sql
```

## Storage Configuration

### Local Storage (Development)

```ruby
# config/storage.yml
local:
  service: Disk
  root: <%= Rails.root.join("storage") %>
```

### AWS S3 (Production)

```ruby
# config/storage.yml
amazon:
  service: S3
  access_key_id: <%= ENV['AWS_ACCESS_KEY_ID'] %>
  secret_access_key: <%= ENV['AWS_SECRET_ACCESS_KEY'] %>
  region: <%= ENV['AWS_REGION'] %>
  bucket: <%= ENV['AWS_BUCKET'] %>
```

#### S3 Bucket Policy
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowFamilyPhotoShareAccess",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::123456789012:user/family-photo-share"
      },
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject"
      ],
      "Resource": "arn:aws:s3:::your-bucket-name/*"
    },
    {
      "Sid": "AllowListBucket",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::123456789012:user/family-photo-share"
      },
      "Action": "s3:ListBucket",
      "Resource": "arn:aws:s3:::your-bucket-name"
    }
  ]
}
```

### Google Cloud Storage

```ruby
# config/storage.yml
google:
  service: GCS
  project: your-project-id
  credentials: <%= ENV['GOOGLE_CLOUD_CREDENTIALS'] %>
  bucket: your-bucket-name
```

## Background Jobs

### Sidekiq Configuration

```ruby
# config/sidekiq.yml
:queues:
  - default
  - image_processing
  - bulk_processing
  - mailers

:scheduler:
  cleanup_expired_sessions:
    cron: '0 2 * * *'  # Daily at 2 AM
    class: ExpiredSessionCleanupJob
```

### Production Scaling

```yaml
# docker-compose.production.yml
sidekiq_default:
  image: family-photo-share:latest
  command: bundle exec sidekiq -q default -c 2
  deploy:
    replicas: 2

sidekiq_image_processing:
  image: family-photo-share:latest
  command: bundle exec sidekiq -q image_processing -c 4
  deploy:
    replicas: 3

sidekiq_bulk_processing:
  image: family-photo-share:latest
  command: bundle exec sidekiq -q bulk_processing -c 2
  deploy:
    replicas: 1
```

### Monitoring Sidekiq

```ruby
# config/routes.rb
require 'sidekiq/web'

Rails.application.routes.draw do
  mount Sidekiq::Web => '/sidekiq' if Rails.env.development?
  # In production, protect with authentication
end
```

## SSL/TLS Configuration

### Let's Encrypt with Nginx

```nginx
# nginx.conf
server {
    listen 80;
    server_name yourdomain.com;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name yourdomain.com;

    ssl_certificate /etc/letsencrypt/live/yourdomain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/yourdomain.com/privkey.pem;
    
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    
    location / {
        proxy_pass http://web:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

### Automatic Certificate Renewal

```bash
# Setup cron job
echo "0 12 * * * /usr/bin/certbot renew --quiet" | crontab -
```

## Monitoring

### Health Checks

```ruby
# config/routes.rb
get '/health', to: 'health#show'

# app/controllers/health_controller.rb
class HealthController < ApplicationController
  def show
    checks = {
      database: database_check,
      redis: redis_check,
      storage: storage_check
    }
    
    status = checks.values.all? ? :ok : :service_unavailable
    render json: { status: status, checks: checks }, status: status
  end

  private

  def database_check
    ActiveRecord::Base.connection.execute('SELECT 1')
    true
  rescue
    false
  end

  def redis_check
    Redis.current.ping == 'PONG'
  rescue
    false
  end

  def storage_check
    ActiveStorage::Blob.service.exist?('health-check')
  rescue
    false
  end
end
```

### Logging

```ruby
# config/environments/production.rb
config.log_level = :info
config.log_tags = [:request_id]

# Use structured logging
config.colorize_logging = false
config.log_formatter = proc do |severity, timestamp, progname, msg|
  {
    timestamp: timestamp.iso8601,
    level: severity,
    message: msg,
    pid: Process.pid
  }.to_json + "\n"
end
```

### Application Performance Monitoring

#### New Relic
```ruby
# Gemfile
gem 'newrelic_rpm'

# config/newrelic.yml
production:
  license_key: <%= ENV['NEW_RELIC_LICENSE_KEY'] %>
  app_name: Family Photo Share
```

#### Sentry Error Tracking
```ruby
# Gemfile
gem 'sentry-ruby'
gem 'sentry-rails'

# config/initializers/sentry.rb
Sentry.init do |config|
  config.dsn = ENV['SENTRY_DSN']
  config.breadcrumbs_logger = [:active_support_logger, :http_logger]
  config.traces_sample_rate = 0.1
end
```

## Backup Strategy

### Automated Backup Script

```bash
#!/bin/bash
# scripts/backup.sh

set -e

DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/backups/$DATE"
mkdir -p $BACKUP_DIR

# Database backup
echo "Backing up database..."
pg_dump $DATABASE_URL | gzip > "$BACKUP_DIR/database.sql.gz"

# Storage backup (if using local storage)
if [ "$ACTIVE_STORAGE_SERVICE" = "local" ]; then
  echo "Backing up storage..."
  tar -czf "$BACKUP_DIR/storage.tar.gz" storage/
fi

# Configuration backup
echo "Backing up configuration..."
cp .env.production "$BACKUP_DIR/env"
cp -r config/ "$BACKUP_DIR/config/"

# Upload to cloud storage
echo "Uploading to S3..."
aws s3 sync $BACKUP_DIR s3://your-backup-bucket/backups/$DATE/

# Clean up local backup
rm -rf $BACKUP_DIR

# Clean up old backups (keep 30 days)
aws s3 ls s3://your-backup-bucket/backups/ | \
  awk '{print $2}' | \
  while read date; do
    if [[ $(date -d "$date" +%s) -lt $(date -d "30 days ago" +%s) ]]; then
      aws s3 rm s3://your-backup-bucket/backups/$date --recursive
    fi
  done

echo "Backup completed successfully"
```

### Backup Verification

```bash
#!/bin/bash
# scripts/verify-backup.sh

BACKUP_DATE=$1
if [ -z "$BACKUP_DATE" ]; then
  echo "Usage: $0 <backup_date>"
  exit 1
fi

# Download backup
aws s3 sync s3://your-backup-bucket/backups/$BACKUP_DATE/ /tmp/backup-verify/

# Verify database backup
echo "Verifying database backup..."
gunzip -c /tmp/backup-verify/database.sql.gz | head -10

# Verify file count
echo "Verifying file count..."
if [ -f "/tmp/backup-verify/storage.tar.gz" ]; then
  tar -tzf /tmp/backup-verify/storage.tar.gz | wc -l
fi

# Clean up
rm -rf /tmp/backup-verify/

echo "Backup verification completed"
```

## Troubleshooting

### Common Issues

#### Database Connection Issues

```bash
# Check database connectivity
docker-compose exec web rails db:migrate:status

# Check PostgreSQL logs
docker-compose logs postgres

# Reset database connection
docker-compose restart web
```

#### Redis Connection Issues

```bash
# Check Redis connectivity
docker-compose exec web rails console
> Redis.current.ping

# Check Redis logs
docker-compose logs redis

# Clear Redis cache
docker-compose exec redis redis-cli FLUSHALL
```

#### Image Processing Issues

```bash
# Check ImageMagick installation
docker-compose exec web convert -version

# Check ExifTool installation
docker-compose exec web exiftool -ver

# Process stuck jobs
docker-compose exec web rails console
> Sidekiq::Queue.new('image_processing').clear
```

#### Storage Issues

```bash
# Check storage service
docker-compose exec web rails console
> ActiveStorage::Blob.service.class

# Check S3 connectivity (if using S3)
> ActiveStorage::Blob.service.bucket.exists?

# Clean up orphaned blobs
docker-compose exec web rake storage:cleanup
```

### Debug Mode

```bash
# Enable debug logging
docker-compose exec web rails console
> Rails.logger.level = Logger::DEBUG

# Check application logs
docker-compose logs -f web

# Check background job logs
docker-compose logs -f sidekiq
```

### Performance Troubleshooting

#### Database Performance

```sql
-- Check slow queries
SELECT query, mean_time, calls 
FROM pg_stat_statements 
ORDER BY mean_time DESC 
LIMIT 10;

-- Check database connections
SELECT * FROM pg_stat_activity;

-- Check table sizes
SELECT schemaname, tablename, 
       pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as size
FROM pg_tables 
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;
```

#### Memory Usage

```bash
# Check memory usage
docker stats

# Check Ruby memory usage
docker-compose exec web rails console
> GC.stat
> ObjectSpace.each_object.count
```

#### Disk Usage

```bash
# Check disk usage
df -h

# Check Docker volume usage
docker system df

# Clean up unused images
docker system prune -a
```

For more troubleshooting help, see the [GitHub Issues](https://github.com/yourusername/family-photo-share/issues) or check the application logs.