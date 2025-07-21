# Family Photo Share - TrueNAS SCALE Deployment

A Ruby on Rails application for private family photo sharing, optimized for deployment on TrueNAS SCALE.

## Quick Start

### Prerequisites
- TrueNAS SCALE 22.12+
- Docker service enabled
- 4GB+ RAM for applications
- Storage pool configured

### Installation

1. **Download and extract** the deployment package
2. **Load the Docker image:**
   ```bash
   docker load < family_photo_share_image.tar.gz
   ```

3. **Configure environment:**
   ```bash
   cp .env.example .env.production
   nano .env.production
   ```

4. **Deploy:**
   ```bash
   docker-compose -f docker-compose.production.yml --env-file .env.production up -d
   ```

5. **Access:** Navigate to `http://your-truenas-ip:3000`

### Essential Configuration

Edit `.env.production` with these required values:

```env
# From config/master.key file
RAILS_MASTER_KEY=your_master_key_here

# Generate with: openssl rand -hex 64
SECRET_KEY_BASE=your_secret_key_here

# Database security
POSTGRES_PASSWORD=your_secure_password

# Network settings
APP_HOST=your-truenas-ip-or-domain
APP_PORT=3000

# Optional: Create admin user on first run
ADMIN_EMAIL=admin@example.com
ADMIN_PASSWORD=secure_password
```

## Features

- **Private photo sharing** for families
- **Album organization** with cover photos
- **Role-based access** (owner/editor/viewer)
- **External sharing** with password protection
- **Background image processing** with multiple size variants
- **Family invitation system**
- **Responsive design** for mobile and desktop

## Storage Layout

```
/mnt/your-pool/apps/family-photo-share/
├── postgres_data/           # Database files
├── redis_data/             # Redis cache
├── rails_storage/          # Uploaded photos
└── rails_public/           # Static assets
```

## Default Ports

- **Web Interface:** 3000
- **PostgreSQL:** 5432 (internal)
- **Redis:** 6379 (internal)

## Resource Requirements

- **Minimum:** 2GB RAM, 2 CPU cores
- **Recommended:** 4GB RAM, 4 CPU cores
- **Storage:** 100GB+ for photos, 10GB for database

## Backup Strategy

```bash
# Database backup
docker exec family_photo_share_postgres pg_dump -U postgres family_photo_share_production > backup.sql

# Photos backup
tar -czf photos_backup.tar.gz rails_storage/
```

## Monitoring

- **Health Check:** `http://your-truenas-ip:3000/up`
- **Logs:** `docker-compose logs -f`
- **Status:** `docker-compose ps`

## Security Notes

- Change all default passwords
- Use strong POSTGRES_PASSWORD
- Consider SSL termination with reverse proxy
- Regular security updates

## Support

- **Documentation:** See `TRUENAS_DEPLOYMENT.md` for detailed setup
- **Logs:** Check application logs for troubleshooting
- **Updates:** Pull new images and restart services

## Services

The application consists of:
- **web:** Main Rails application
- **postgres:** Database server
- **redis:** Cache and job queue
- **sidekiq:** Background job processor
- **sidekiq_image_processing:** Image processing worker

All services restart automatically and include health checks for reliability.