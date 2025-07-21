# Family Photo Share - TrueNAS SCALE Deployment Guide

This guide covers deploying Family Photo Share on TrueNAS SCALE using the custom app system.

## Prerequisites

- TrueNAS SCALE 22.12 or later
- At least 4GB RAM allocated to applications
- Storage pool configured for persistent data

## Installation Options

### Option 1: Docker Compose (Recommended for Testing)

1. **Enable Docker Service**
   - Go to System Settings > Advanced > Init/Shutdown Scripts
   - Enable Docker service

2. **Create Application Dataset**
   ```bash
   # SSH into TrueNAS and create directories
   sudo mkdir -p /mnt/your-pool/apps/family-photo-share
   cd /mnt/your-pool/apps/family-photo-share
   ```

3. **Copy Files**
   ```bash
   # Copy the application files
   git clone https://github.com/streed/family-photo-share.git .
   ```

4. **Configure Environment**
   ```bash
   # Copy and edit environment file
   cp .env.production.example .env.production
   nano .env.production
   ```

   Required variables:
   ```env
   # Generate with: rails secret
   RAILS_MASTER_KEY=your_master_key_from_config_master_key
   SECRET_KEY_BASE=your_generated_secret_key
   
   # Database
   POSTGRES_PASSWORD=your_secure_password
   
   # Application
   APP_HOST=your-truenas-ip-or-domain
   APP_PORT=3000
   
   # Optional: Admin user (created on first run)
   ADMIN_EMAIL=admin@example.com
   ADMIN_PASSWORD=secure_admin_password
   ```

5. **Deploy**
   ```bash
   # Build and start services
   docker-compose -f docker-compose.production.yml --env-file .env.production up -d
   ```

6. **Access Application**
   - Navigate to `http://your-truenas-ip:3000`
   - Login with admin credentials (if configured)

### Option 2: TrueNAS Custom App (Advanced)

1. **Enable Custom Apps**
   - Go to Apps > Manage Catalogs
   - Add custom catalog if needed

2. **Create Application**
   - Use the files in `truenas-app/` directory
   - Configure through TrueNAS UI

## Configuration

### Storage Requirements

- **Photos**: 100GB+ recommended (depends on usage)
- **Database**: 10GB minimum
- **Redis**: 1GB minimum

### Network Configuration

- **Web Port**: 3000 (configurable)
- **Database**: Internal only (5432)
- **Redis**: Internal only (6379)

### Security Considerations

1. **Change Default Passwords**
   - Update POSTGRES_PASSWORD
   - Set strong ADMIN_PASSWORD

2. **SSL/TLS Setup**
   ```bash
   # Use reverse proxy like nginx for SSL
   # Or configure TrueNAS built-in certificates
   ```

3. **Backup Strategy**
   ```bash
   # Database backup
   docker exec family_photo_share_postgres pg_dump -U postgres family_photo_share_production > backup.sql
   
   # Photo backup
   tar -czf photos_backup.tar.gz /mnt/your-pool/apps/family-photo-share/rails_storage/
   ```

## Maintenance

### Updates

```bash
# Pull latest image
docker-compose -f docker-compose.production.yml pull

# Restart services
docker-compose -f docker-compose.production.yml up -d
```

### Database Management

```bash
# Enter database container
docker exec -it family_photo_share_postgres psql -U postgres -d family_photo_share_production

# Run migrations manually
docker exec family_photo_share_web bundle exec rails db:migrate
```

### Scheduled Tasks

The application uses Sidekiq Cron for scheduled tasks:

1. **Guest Session Cleanup** - Runs every hour automatically
   - Removes expired guest access sessions
   - Cleans orphaned sessions
   - Logs statistics about active sessions

2. **View Scheduled Jobs**
   ```bash
   # In development, visit: http://localhost:3000/sidekiq/cron
   
   # Check job status via Rails console
   docker exec -it family_photo_share_web rails console
   > Sidekiq::Cron::Job.all
   ```

3. **Manual Cleanup**
   ```bash
   # Run cleanup manually
   docker exec family_photo_share_web bundle exec rails cleanup:expired_sessions
   
   # Run comprehensive cleanup
   docker exec family_photo_share_web bundle exec rails cleanup:all
   
   # Trigger job via console
   docker exec -it family_photo_share_web rails console
   > CleanupExpiredSessionsJob.perform_now
   ```

### Logs

```bash
# View application logs
docker-compose -f docker-compose.production.yml logs -f web

# View all logs
docker-compose -f docker-compose.production.yml logs -f
```

## Troubleshooting

### Common Issues

1. **Database Connection Issues**
   ```bash
   # Check database status
   docker-compose -f docker-compose.production.yml ps postgres
   
   # Check database logs
   docker-compose -f docker-compose.production.yml logs postgres
   ```

2. **Permission Issues**
   ```bash
   # Fix storage permissions
   sudo chown -R 1000:1000 /mnt/your-pool/apps/family-photo-share/rails_storage/
   ```

3. **Memory Issues**
   ```bash
   # Check resource usage
   docker stats
   
   # Restart services
   docker-compose -f docker-compose.production.yml restart
   ```

### Performance Tuning

1. **Database Optimization**
   ```sql
   -- Connect to database and optimize
   VACUUM ANALYZE;
   REINDEX DATABASE family_photo_share_production;
   ```

2. **Image Processing**
   - Adjust Sidekiq worker count in docker-compose.production.yml
   - Monitor CPU/memory usage during bulk uploads

3. **Storage Optimization**
   - Use SSD for database storage
   - Regular photo storage can use HDD

## Backup and Restore

### Automated Backup Script

```bash
#!/bin/bash
BACKUP_DIR="/mnt/your-pool/backups/family-photo-share"
DATE=$(date +%Y%m%d_%H%M%S)

# Create backup directory
mkdir -p $BACKUP_DIR

# Backup database
docker exec family_photo_share_postgres pg_dump -U postgres family_photo_share_production | gzip > $BACKUP_DIR/db_$DATE.sql.gz

# Backup photos (incremental)
rsync -av --delete /mnt/your-pool/apps/family-photo-share/rails_storage/ $BACKUP_DIR/photos/

# Keep only last 7 days
find $BACKUP_DIR -name "db_*.sql.gz" -mtime +7 -delete
```

### Restore Process

```bash
# Restore database
gunzip -c backup.sql.gz | docker exec -i family_photo_share_postgres psql -U postgres family_photo_share_production

# Restore photos
rsync -av backup/photos/ /mnt/your-pool/apps/family-photo-share/rails_storage/
```

## Monitoring

### Health Checks

The application includes built-in health checks at `/up` endpoint.

### Resource Monitoring

```bash
# Monitor container resources
docker-compose -f docker-compose.production.yml top

# Check disk usage
df -h /mnt/your-pool/apps/family-photo-share/
```

## Support

For issues and questions:
1. Check application logs
2. Review TrueNAS system logs
3. Check GitHub issues
4. Community forums