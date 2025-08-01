# Docker Setup Guide

This guide explains how to run Family Photo Share using Docker Compose.

## Quick Start

1. **Copy environment variables:**
   ```bash
   cp .env.example .env
   # Edit .env with your actual values
   ```

2. **Start all services:**
   ```bash
   docker-compose up -d
   ```

3. **Check service status:**
   ```bash
   docker-compose ps
   ```

4. **View logs:**
   ```bash
   docker-compose logs -f
   ```

## Service Architecture

### Infrastructure Services
- **postgres**: PostgreSQL 15 database with health checks
- **redis**: Redis 7 for Sidekiq job queue with persistence

### Application Services  
- **web**: Rails application server (port 3000)
- **sidekiq**: Main worker for general jobs
- **sidekiq_cron**: Scheduled job worker
- **sidekiq_image_processing**: Dedicated image processing worker (4 threads)

## Development Workflow

### Starting Services

```bash
# Start all services
docker-compose up -d

# Start only infrastructure (for local Rails development)
docker-compose up postgres redis -d

# Rebuild and start (after Gemfile changes)
docker-compose build
docker-compose up -d
```

### Viewing Logs

```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f web
docker-compose logs -f sidekiq
```

### Accessing Services

- **Rails App**: http://localhost:3000
- **PostgreSQL**: localhost:5433
- **Redis**: localhost:6380

### Database Management

```bash
# Run migrations
docker-compose exec web rails db:migrate

# Access Rails console
docker-compose exec web rails console

# Access database console
docker-compose exec postgres psql -U postgres family_photo_share_development
```

### Stopping Services

```bash
# Stop all services
docker-compose down

# Stop and remove volumes (careful - deletes data!)
docker-compose down -v
```

## Troubleshooting

### Port Conflicts

If you get port already in use errors, the docker-compose.yml uses non-standard ports:
- PostgreSQL: 5433 (instead of 5432)
- Redis: 6380 (instead of 6379)

### Permission Issues

If you encounter permission errors with volumes:

```bash
# Fix ownership
docker-compose exec web chown -R rails:rails /rails/storage
```

### Database Connection Issues

Ensure the database is healthy:

```bash
docker-compose ps
# Should show postgres as "healthy"
```

### Sidekiq Not Processing Jobs

Check Sidekiq logs:

```bash
docker-compose logs sidekiq
docker-compose logs sidekiq_image_processing
```

## Environment Variables

See `.env.example` for all available configuration options. Key variables:

- `POSTGRES_PASSWORD`: Database password
- `RAILS_MASTER_KEY`: Rails encryption key
- `REDIS_URL`: Redis connection string
- `DATABASE_URL`: PostgreSQL connection string

### Email Configuration (Gmail)

To send invitation emails, add these to your `.env`:

```bash
SMTP_ADDRESS=smtp.gmail.com
SMTP_PORT=587
SMTP_DOMAIN=gmail.com
SMTP_USERNAME=your-gmail-username
SMTP_PASSWORD=your-app-password  # 16-character app password from Google
SMTP_AUTHENTICATION=plain
SMTP_ENABLE_STARTTLS_AUTO=true
```

Test email sending:
```bash
docker-compose exec web rails email:test TEST_EMAIL=recipient-username
```

## Docker Compose Commands Reference

| Command | Description |
|---------|-------------|
| `docker-compose up -d` | Start all services in background |
| `docker-compose ps` | List running services |
| `docker-compose logs -f [service]` | View logs (follow mode) |
| `docker-compose exec [service] [command]` | Run command in service |
| `docker-compose down` | Stop all services |
| `docker-compose build` | Rebuild images |
| `docker-compose restart [service]` | Restart specific service |