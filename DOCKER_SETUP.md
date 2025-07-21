# Docker Setup Guide

This guide explains how to run the Family Photo Share application with Sidekiq workers using Docker Compose.

## Quick Start

### Development Setup

1. **Copy environment variables:**
   ```bash
   cp .env.example .env
   # Edit .env with your actual values
   ```

2. **Start infrastructure only (for local development):**
   ```bash
   docker-compose up postgres redis
   ```

3. **Start with Sidekiq workers (full development):**
   ```bash
   docker-compose -f docker-compose.dev.yml up
   ```

### Production Setup

1. **Set environment variables:**
   ```bash
   cp .env.example .env.production
   # Edit .env.production with production values
   ```

2. **Start production services:**
   ```bash
   docker-compose -f docker-compose.prod.yml up -d
   ```

## Service Architecture

### Infrastructure Services
- **postgres**: PostgreSQL 15 database with health checks
- **redis**: Redis 7 for Sidekiq job queue with persistence

### Application Services  
- **web**: Rails application server (port 3000 in dev, 80 in prod)
- **sidekiq**: Main worker for general jobs (5 threads)
- **sidekiq_images**: Dedicated image processing worker (4 threads)
- **sidekiq_bulk**: Bulk processing worker (2 threads)

## Sidekiq Workers

### Queue Configuration

| Queue | Purpose | Worker | Concurrency |
|-------|---------|--------|-------------|
| `default` | General application jobs | `sidekiq` | 5 |
| `image_processing` | Photo thumbnail generation | `sidekiq_images` | 4 |
| `bulk_processing` | Batch operations | `sidekiq_bulk` | 2 |

### Worker Specialization

- **Main Worker**: Handles user-facing jobs (emails, notifications)
- **Image Worker**: CPU-intensive thumbnail generation
- **Bulk Worker**: Background maintenance and batch operations

## Docker Compose Files

### `docker-compose.yml` (Default)
- Full application stack for development
- Uses built Docker image
- Suitable for testing production-like environment

### `docker-compose.dev.yml` (Development)
- Uses Ruby base image for faster iteration
- Volume mounts for live code reloading
- Separate containers for each worker type

### `docker-compose.prod.yml` (Production)
- Production-optimized configuration
- Health checks and resource limits
- Proper logging and restart policies

## Environment Variables

### Required Variables
```bash
RAILS_MASTER_KEY=your_rails_master_key
POSTGRES_PASSWORD=secure_database_password
DATABASE_URL=postgresql://postgres:password@postgres:5432/database_name
REDIS_URL=redis://redis:6379/0
```

### Optional Variables
```bash
SIDEKIQ_USERNAME=admin
SIDEKIQ_PASSWORD=secure_password
MAX_IMAGE_SIZE=10485760
SIDEKIQ_CONCURRENCY=5
```

## Usage Commands

### Start Services
```bash
# Development (infrastructure only)
docker-compose up postgres redis

# Development (full stack)
docker-compose -f docker-compose.dev.yml up

# Production
docker-compose -f docker-compose.prod.yml up -d
```

### Stop Services
```bash
docker-compose down
# or
docker-compose -f docker-compose.dev.yml down
# or  
docker-compose -f docker-compose.prod.yml down
```

### View Logs
```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f sidekiq_images

# Specific worker type
docker-compose -f docker-compose.dev.yml logs -f sidekiq_images
```

### Execute Commands
```bash
# Rails console
docker-compose exec web rails console

# Run migrations
docker-compose exec web rails db:migrate

# Process images
docker-compose exec web rails images:process_all

# Check processing status
docker-compose exec web rails images:status
```

## Monitoring

### Sidekiq Web UI
- **Development**: http://localhost:3000/sidekiq (if enabled in routes)
- **Production**: Access through Rails application with authentication

### Container Health
```bash
# Check container status
docker-compose ps

# Check service health
docker-compose exec postgres pg_isready -U postgres
docker-compose exec redis redis-cli ping
```

### Worker Status
```bash
# Check active jobs
docker-compose exec web rails runner "puts Sidekiq::Queue.new.size"

# Check failed jobs
docker-compose exec web rails runner "puts Sidekiq::RetrySet.new.size"

# Check processing status
docker-compose exec web rails images:status
```

## Scaling Workers

### Horizontal Scaling
```bash
# Scale image processing workers
docker-compose up --scale sidekiq_images=3

# Scale with specific compose file
docker-compose -f docker-compose.prod.yml up --scale sidekiq_images=4 -d
```

### Vertical Scaling
Edit the concurrency in `config/sidekiq.yml` or set environment variables:
```bash
SIDEKIQ_CONCURRENCY=10 docker-compose up
```

## Troubleshooting

### Common Issues

1. **Port conflicts**: Change ports in docker-compose.yml if 5433/6380 are in use
2. **Permission errors**: Ensure proper file permissions for storage volumes
3. **Memory issues**: Increase Docker memory limits for image processing
4. **Database connection**: Ensure postgres service is healthy before starting app

### Debug Commands
```bash
# Check container logs
docker-compose logs sidekiq_images

# Access container shell
docker-compose exec sidekiq_images bash

# Check Redis connection
docker-compose exec web rails runner "puts Redis.new.ping"

# Check database connection  
docker-compose exec web rails runner "puts ActiveRecord::Base.connection.active?"
```

### Performance Tuning

1. **Image Processing**: Increase `sidekiq_images` concurrency for faster processing
2. **Memory**: Monitor container memory usage and adjust limits
3. **Storage**: Use SSD for faster image processing
4. **Network**: Ensure low latency between services

## Production Considerations

1. **Use external Redis/PostgreSQL** for better performance and reliability
2. **Set up proper logging** aggregation (ELK, Splunk, etc.)
3. **Configure monitoring** (New Relic, DataDog, etc.)
4. **Set resource limits** to prevent resource exhaustion
5. **Use health checks** for automatic recovery
6. **Backup strategy** for data volumes