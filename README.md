# Family Photo Share

A Ruby on Rails application that allows families to share photos privately. Users can create accounts, upload photos to albums, invite family members, and manage access with role-based permissions.

## Tech Stack

- **Backend**: Ruby on Rails 7.x
- **Database**: PostgreSQL
- **File Storage**: Active Storage (for photo uploads)
- **Background Jobs**: Sidekiq with Redis
- **Authentication**: Devise + OmniAuth (Google OAuth)
- **Frontend**: ERB templates with JavaScript for dynamic features

## Prerequisites

- Ruby 3.x
- Rails 7.x
- Docker and Docker Compose (for PostgreSQL and Redis)
- Git

## Setup Instructions

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd family-photo-share
   ```

2. **Install dependencies**
   ```bash
   bundle install
   ```

3. **Start database and Redis services**
   ```bash
   docker-compose up -d
   ```

4. **Setup database**
   ```bash
   rails db:create
   rails db:migrate
   ```

5. **Start the Rails server**
   ```bash
   rails server
   ```

6. **Visit the application**
   Open your browser and go to `http://localhost:3000`

## Development Commands

```bash
# Start development services
docker-compose up -d

# Start Rails server
rails server

# Run Rails console
rails console

# Run database migrations
rails db:migrate

# Run tests (after test setup)
bundle exec rspec

# Run code linting
bundle exec rubocop

# Stop development services
docker-compose down
```

## Database Configuration

The application uses PostgreSQL running in a Docker container:
- Host: localhost
- Port: 5433
- Username: postgres
- Password: password
- Development DB: family_photo_share_development
- Test DB: family_photo_share_test

## Services

- **PostgreSQL**: Database server (Docker container on port 5433)
- **Redis**: Background job queue and caching (Docker container on port 6380)
- **Sidekiq**: Background job processor (future implementation)

## Project Structure

- `app/` - Rails application code (models, views, controllers)
- `config/` - Configuration files
- `db/` - Database migrations and schema
- `tickets/` - Development tickets organized by phases
- `docker-compose.yml` - Development services configuration

## Development Process

This project follows a ticket-based development approach. See the `tickets/` folder for organized development phases:

1. **Phase 1**: Project Setup & Infrastructure
2. **Phase 2**: Authentication & User Management  
3. **Phase 3**: Core Photo Features
4. **Phase 4**: Family & Sharing System
5. **Phase 5**: Albums & Advanced Features
6. **Phase 6**: Polish & Testing

Each ticket includes detailed implementation steps, acceptance criteria, and testing requirements.