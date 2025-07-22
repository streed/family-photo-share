# Family Photo Share

A self-hosted Ruby on Rails application for families to share photos privately. Create albums, invite family members, and manage access with role-based permissions - all while keeping your precious memories under your control.

## Features

- 📸 **Photo Management**: Upload, organize, and share photos with your family
- 👨‍👩‍👧‍👦 **Family Groups**: Create private family spaces with invite-only access
- 📚 **Albums**: Organize photos into albums with customizable privacy settings
- 🔒 **Privacy Controls**: Private and family-only album permissions
- 🖼️ **Image Processing**: Automatic thumbnail generation and image optimization
- 📧 **Invitations**: Email-based family member invitations
- 🎨 **Responsive Design**: Works great on desktop and mobile devices
- 🚀 **Background Processing**: Efficient image processing using Sidekiq

## Tech Stack

- **Backend**: Ruby on Rails 8.0
- **Database**: PostgreSQL 15
- **File Storage**: Active Storage with local or cloud storage support
- **Background Jobs**: Sidekiq with Redis
- **Authentication**: Devise with secure invite-only registration
- **Image Processing**: ImageMagick/libvips
- **Frontend**: ERB templates with Stimulus.js

## Prerequisites

- Docker and Docker Compose
- Ruby 3.4.2 (for local development)
- Git

## Quick Start

### Using Docker (Recommended)

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/family-photo-share.git
   cd family-photo-share
   ```

2. **Copy environment configuration**
   ```bash
   cp .env.example .env
   # Edit .env with your settings
   ```

3. **Start the application**
   ```bash
   docker-compose up -d
   ```

4. **Visit the application**
   Open your browser and go to `http://localhost:3000`

### Local Development

1. **Install dependencies**
   ```bash
   bundle install
   ```

2. **Start PostgreSQL and Redis**
   ```bash
   docker-compose up postgres redis -d
   ```

3. **Setup database**
   ```bash
   rails db:create db:migrate
   ```

4. **Start the Rails server**
   ```bash
   rails server
   ```

5. **Start Sidekiq (in another terminal)**
   ```bash
   bundle exec sidekiq
   ```

## Environment Variables

Copy `.env.example` to `.env` and configure the following variables:

### Required Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `POSTGRES_DB` | Database name | `family_photo_share_production` |
| `POSTGRES_USER` | Database username | `postgres` |
| `POSTGRES_PASSWORD` | Database password | `your_secure_password` |
| `RAILS_MASTER_KEY` | Rails encryption key (from config/master.key) | `your_master_key` |
| `SECRET_KEY_BASE` | Rails secret key (generate with `rails secret`) | `your_secret_key` |

### Optional Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `APP_HOST` | Application hostname | `localhost` |
| `APP_PORT` | Application port | `3000` |
| `ADMIN_EMAIL` | Initial admin email (created on first startup) | - |
| `ADMIN_PASSWORD` | Initial admin password | - |
| `ACTIVE_STORAGE_VARIANT_PROCESSOR` | Image processor (`vips` or `mini_magick`) | `vips` |
| `FORCE_SSL` | Force HTTPS in production | `false` |

### Email Configuration (Gmail)

To enable email sending for family invitations, configure Gmail SMTP:

1. **Enable 2-factor authentication** on your Google account
2. **Generate an App Password** at https://myaccount.google.com/apppasswords
3. **Configure these variables** with your Gmail settings:

| Variable | Description | Gmail Example |
|----------|-------------|---------------|
| `SMTP_ADDRESS` | SMTP server address | `smtp.gmail.com` |
| `SMTP_PORT` | SMTP server port | `587` |
| `SMTP_DOMAIN` | SMTP domain | `gmail.com` |
| `SMTP_USERNAME` | Your Gmail address | `your-email@gmail.com` |
| `SMTP_PASSWORD` | 16-character app password | `xxxx xxxx xxxx xxxx` |
| `SMTP_AUTHENTICATION` | Authentication method | `plain` |
| `SMTP_ENABLE_STARTTLS_AUTO` | Enable STARTTLS | `true` |

**Test your email configuration:**
```bash
TEST_EMAIL=your@email.com rails email:test
```

## Usage

### Creating Your First Family

1. Sign up using an invitation link (the app is invite-only)
2. Create a family group from your dashboard
3. Invite family members via email
4. Start creating albums and uploading photos!

### Album Privacy Settings

- **Private**: Only you can see the album
- **Family**: All family members can view the album

### Managing Family Members

Family members have three roles:
- **Admin**: Can invite/remove members and manage family settings
- **Member**: Can view family albums and upload photos
- **Viewer**: Can only view family albums (coming soon)

## Development

### Running Tests
```bash
bundle exec rspec
```

### Code Linting
```bash
bundle exec rubocop
```

### Database Commands
```bash
# Create database
rails db:create

# Run migrations
rails db:migrate

# Seed database (development only)
rails db:seed
```

### Docker Commands
```bash
# Start all services
docker-compose up -d

# View logs
docker-compose logs -f

# Stop all services
docker-compose down

# Rebuild images
docker-compose build
```

## Project Structure

```
family-photo-share/
├── app/              # Rails application code
│   ├── controllers/  # Request handlers
│   ├── models/       # Data models
│   ├── views/        # HTML templates
│   ├── jobs/         # Background jobs
│   └── javascript/   # Stimulus controllers
├── config/           # Configuration files
├── db/               # Database migrations
├── spec/             # Test files
├── docker-compose.yml # Docker services
└── .env.example      # Environment template
```

## Contributing

We welcome contributions! Please feel free to submit a Pull Request. For major changes, please open an issue first to discuss what you would like to change.

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## Security

- The application uses invite-only registration to prevent unauthorized access
- All passwords are encrypted using bcrypt
- File uploads are validated and processed in background jobs
- Session-based rate limiting prevents brute force attacks
- CSRF protection is enabled by default

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Built with Ruby on Rails
- Uses Docker for easy deployment
- Inspired by the need for private, self-hosted photo sharing