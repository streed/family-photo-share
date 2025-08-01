# Family Photo Share

[![Ruby](https://img.shields.io/badge/ruby-3.4.2-red.svg)](https://www.ruby-lang.org/)
[![Rails](https://img.shields.io/badge/rails-8.0.2-red.svg)](https://rubyonrails.org/)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-15-blue.svg)](https://www.postgresql.org/)
[![Redis](https://img.shields.io/badge/Redis-7-red.svg)](https://redis.io/)
[![Docker](https://img.shields.io/badge/docker-ready-blue.svg)](https://www.docker.com/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A modern, secure photo-sharing platform designed for families. Built with Ruby on Rails, this application provides a private space for families to share, organize, and preserve their memories together.

## Table of Contents

- [Features](#features)
- [Demo](#demo)
- [Tech Stack](#tech-stack)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Development](#development)
- [Production Deployment](#production-deployment)
- [Usage Guide](#usage-guide)
- [Architecture](#architecture)
- [API Documentation](#api-documentation)
- [Testing](#testing)
- [Contributing](#contributing)
- [Security](#security)
- [License](#license)

## Features

### Core Features
- 📸 **Photo Management**: Upload, organize, and manage photos with automatic metadata extraction
- 👨‍👩‍👧‍👦 **Family Groups**: Create private family spaces with secure member management
- 📚 **Smart Albums**: Organize photos with automatic date-based sorting using EXIF data
- 🔒 **Privacy Controls**: Granular privacy settings (private, family, external sharing)
- 🎯 **Bulk Upload**: Upload up to 100 photos at once with real-time progress tracking
- 🔗 **External Sharing**: Share albums via password-protected links with guest session tracking
- 🖼️ **Image Processing**: Automatic thumbnail generation and multiple image variants
- 📱 **Responsive Design**: Optimized for desktop, tablet, and mobile devices
- 🎬 **Slideshow Mode**: Beautiful fullscreen photo viewing experience
- 📍 **Location Data**: Automatic GPS extraction and mapping (when available)

### Security Features
- 🔐 **Authentication**: Secure user authentication with Devise
- 🛡️ **Rate Limiting**: Protection against brute force attacks with progressive lockouts
- 👥 **Session Management**: Track and revoke external access sessions
- 🔑 **Password Protection**: Optional passwords for shared albums
- 📧 **Two-Factor Authentication**: Email-based verification (optional)

### Technical Features
- ⚡ **Background Processing**: Sidekiq for asynchronous job processing
- 💾 **Flexible Storage**: Support for local and cloud storage (S3, GCS)
- 🔄 **Real-time Updates**: Hotwire (Turbo + Stimulus) for seamless interactions
- 📊 **Monitoring**: Built-in metrics and health checks
- 🐳 **Docker Ready**: Complete Docker and Docker Compose setup
- 🧪 **Comprehensive Testing**: Full RSpec test suite with high coverage

## Demo

![Family Photo Share Demo](docs/images/demo.gif)

*Note: Demo images can be added to the docs/images directory*

## Tech Stack

- **Backend Framework**: Ruby on Rails 8.0.2
- **Ruby Version**: 3.4.2
- **Database**: PostgreSQL 15
- **Cache/Queue**: Redis 7
- **Job Processing**: Sidekiq
- **File Storage**: Active Storage (Local/S3/GCS)
- **Image Processing**: ImageMagick + libvips
- **Frontend**: Hotwire (Turbo + Stimulus), Bootstrap 5
- **Authentication**: Devise
- **Testing**: RSpec, FactoryBot, Capybara

## Prerequisites

### Using Docker (Recommended)
- Docker 20.10+
- Docker Compose 2.0+
- Git

### Local Development
- Ruby 3.4.2
- PostgreSQL 15+
- Redis 7+
- ImageMagick 7+
- ExifTool
- Node.js 18+ and Yarn
- Git

## Quick Start

### 🐳 Using Docker (Recommended)

```bash
# 1. Clone the repository
git clone https://github.com/streed/family-photo-share.git
cd family-photo-share

# 2. Copy and configure environment variables
cp .env.example .env
# Edit .env with your settings

# 3. Generate Rails master key
echo "$(docker run --rm ruby:3.4.2 sh -c 'ruby -rsecurerandom -e "puts SecureRandom.hex(32)"')" > .env
# Add as RAILS_MASTER_KEY in .env

# 4. Start all services
docker-compose up -d

# 5. Setup database
docker-compose exec web rails db:create db:migrate db:seed

# 6. Visit http://localhost:3000
```

### 💻 Local Development

```bash
# 1. Clone and install dependencies
git clone https://github.com/streed/family-photo-share.git
cd family-photo-share
bundle install
yarn install

# 2. Install system dependencies (macOS)
brew install postgresql@15 redis imagemagick exiftool

# 3. Setup database
cp config/database.yml.example config/database.yml
rails db:create db:migrate db:seed

# 4. Start services
# Terminal 1: Rails server
rails server

# Terminal 2: Sidekiq
bundle exec sidekiq

# Terminal 3: Redis (if not running)
redis-server
```

## Development

### 🛠️ Development Setup

```bash
# Run all services with Docker
docker-compose up

# Access Rails console
docker-compose exec web rails console

# Run database migrations
docker-compose exec web rails db:migrate

# View logs
docker-compose logs -f web
docker-compose logs -f sidekiq
```

### 📝 Code Style

We use RuboCop for Ruby code style:

```bash
# Run linter
docker-compose exec web rubocop

# Auto-fix issues
docker-compose exec web rubocop -a
```

### 🧪 Testing

```bash
# Run all tests
docker-compose exec web rspec

# Run specific test
docker-compose exec web rspec spec/models/photo_spec.rb

# Run with coverage
docker-compose exec web COVERAGE=true rspec

# Run system tests
docker-compose exec web rspec spec/system
```

### 📚 Documentation

- [Architecture Overview](docs/ARCHITECTURE.md)
- [API Documentation](docs/API.md)
- [Deployment Guide](docs/DEPLOYMENT.md)
- [Contributing Guidelines](CONTRIBUTING.md)
- [Error Handling Guide](docs/ERROR_HANDLING.md)

## Production Deployment

### 🚀 Docker Production Deployment

```bash
# 1. Setup production environment
cp .env.production.example .env.production
# Configure with production values

# 2. Build production image
docker build -t family-photo-share:latest .

# 3. Run with production compose
docker-compose -f docker-compose.production.yml up -d

# 4. Run production migrations
docker-compose -f docker-compose.production.yml exec web rails db:migrate
```

### 🔧 Environment Variables

#### Required Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `RAILS_MASTER_KEY` | Rails encryption key | `your-32-char-hex-key` |
| `DATABASE_URL` | PostgreSQL connection string | `postgresql://user:pass@host/db` |
| `REDIS_URL` | Redis connection string | `redis://localhost:6379/0` |

#### Optional Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `RAILS_ENV` | Environment | `production` |
| `RAILS_LOG_TO_STDOUT` | Log to stdout | `true` |
| `RAILS_SERVE_STATIC_FILES` | Serve static files | `false` |
| `FORCE_SSL` | Force HTTPS | `true` |
| `AWS_ACCESS_KEY_ID` | AWS S3 access key | - |
| `AWS_SECRET_ACCESS_KEY` | AWS S3 secret | - |
| `AWS_REGION` | AWS region | `us-east-1` |
| `AWS_BUCKET` | S3 bucket name | - |

#### Email Configuration

| Variable | Description | Example |
|----------|-------------|---------|
| `SMTP_ADDRESS` | SMTP server | `smtp.gmail.com` |
| `SMTP_PORT` | SMTP port | `587` |
| `SMTP_USERNAME` | SMTP username | `your-smtp-username` |
| `SMTP_PASSWORD` | SMTP password | `app-specific-password` |
| `SMTP_DOMAIN` | SMTP domain | `your-domain.com` |

### 📊 Monitoring & Maintenance

#### Health Checks
```bash
# Application health
curl http://localhost:3000/health

# Sidekiq health
curl http://localhost:3000/sidekiq/stats
```

#### Maintenance Tasks
```bash
# Clean expired sessions
docker-compose exec web rake sessions:cleanup

# Update EXIF data
docker-compose exec web rake photos:update_exif_direct

# Clean orphaned storage
docker-compose exec web rake storage:cleanup

# Show photo statistics
docker-compose exec web rake photos:exif_stats
```

## Usage Guide

### 👤 User Management

1. **Sign Up**: Create your account (first user becomes admin)
2. **Create Family**: Set up your family group
3. **Invite Members**: Send email invitations to family members

### 📸 Photo Management

1. **Upload Photos**:
   - Single or bulk upload (up to 100 files)
   - Supported formats: JPEG, PNG, GIF, HEIC, WEBP
   - Automatic EXIF extraction

2. **Organize Albums**:
   - Create albums with privacy settings
   - Add/remove photos
   - Set cover photos
   - Share externally with passwords

3. **View Photos**:
   - Grid or slideshow view
   - Full metadata display
   - Download originals

### 🔗 External Sharing

1. Create album with "External" privacy
2. Optional: Set password protection
3. Share the generated link
4. Monitor guest access and sessions

## Architecture

### 📋 Data Models

```ruby
User (Devise authentication)
├── Family (belongs_to)
├── Photos (has_many)
└── Albums (has_many)

Photo
├── User (belongs_to)
├── Albums (has_and_belongs_to_many)
├── Active Storage attachment
└── EXIF metadata (JSON)

Album
├── User (belongs_to)
├── Photos (has_and_belongs_to_many)
├── Privacy settings
└── External access sessions
```

### 🔄 Background Jobs

- `ExtractPhotoMetadataJob`: EXIF data extraction
- `ProcessPhotoJob`: Image variant generation
- `BulkUploadProcessingJob`: Batch upload handling
- `DirectBulkExifUpdateJob`: Bulk metadata updates
- `ExpiredSessionCleanupJob`: Session maintenance

### 📁 Directory Structure

```
family-photo-share/
├── app/
│   ├── controllers/      # Request handlers
│   ├── models/          # Data models
│   ├── views/           # View templates
│   ├── jobs/            # Background jobs
│   ├── javascript/      # Stimulus controllers
│   └── helpers/         # View helpers
├── config/              # Rails configuration
├── db/                  # Database files
├── lib/                 # Custom tasks
├── spec/                # Test suite
├── docs/                # Documentation
└── docker/              # Docker configs
```

## API Documentation

See [API Documentation](docs/API.md) for detailed endpoint information.

### Key Endpoints

- `GET /api/v1/photos` - List photos
- `POST /api/v1/photos` - Upload photo
- `GET /api/v1/albums` - List albums
- `POST /api/v1/albums` - Create album

## Testing

### Test Coverage

We maintain high test coverage across:
- Models (100%)
- Controllers (95%+)
- Jobs (90%+)
- System tests for critical paths

### Running Tests

```bash
# Full test suite
make test

# Specific tests
make test-models
make test-controllers
make test-system

# With coverage report
make test-coverage
```

## Contributing

We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md) for details.

### Quick Contribution Guide

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Write tests for your changes
4. Ensure all tests pass
5. Commit your changes (`git commit -m 'Add amazing feature'`)
6. Push to the branch (`git push origin feature/amazing-feature`)
7. Open a Pull Request

### Development Standards

- Follow Ruby style guide (RuboCop)
- Write comprehensive tests
- Document public APIs
- Keep commits atomic
- Update CHANGELOG.md

## Security

### 🔒 Security Features

- Invite-only registration
- Password encryption (bcrypt)
- CSRF protection
- SQL injection prevention
- XSS protection
- Rate limiting
- Session expiration
- Secure file uploads

### 🐛 Reporting Security Issues

Please report security vulnerabilities through GitHub's private vulnerability reporting feature. See SECURITY.md for details.

Do not open public issues for security concerns.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Ruby on Rails community
- Open source contributors
- [ImageMagick](https://imagemagick.org/)
- [ExifTool](https://exiftool.org/)
- [Bootstrap](https://getbootstrap.com/)

## Support

- 📚 [Documentation](docs/)
- 💬 [Discussions](https://github.com/streed/family-photo-share/discussions)
- 🐛 [Issue Tracker](https://github.com/streed/family-photo-share/issues)
- 💬 [GitHub Discussions](https://github.com/streed/family-photo-share/discussions)

---

Built with ❤️ for families everywhere